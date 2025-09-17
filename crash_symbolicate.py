#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
iOS Crash 符号化工具
用法: python3 crash_symbolicate.py <crash.log> <dsym_path>
"""

import sys
import re
import subprocess
import os
from pathlib import Path

class CrashSymbolicator:
    def __init__(self, crash_file, dsym_path):
        self.crash_file = crash_file
        self.dsym_path = dsym_path
        self.binary_images = {}
        self.symbolicated_lines = []
        
    def parse_binary_images(self, content):
        """解析Binary Images部分，提取库信息"""
        binary_section = re.search(r'Binary Images:(.*?)$', content, re.DOTALL)
        if not binary_section:
            return
            
        for line in binary_section.group(1).strip().split('\n'):
            line = line.strip()
            if not line:
                continue
                
            # 解析格式: 0x地址 - 0x地址 +库名 架构 <UUID> 路径
            match = re.match(r'(0x[a-f0-9]+)\s+-\s+(0x[a-f0-9]+)\s+\+?([^\s]+)\s+arm64\s+<([a-f0-9-]+)>\s+(.+)', line)
            if match:
                start_addr, end_addr, lib_name, uuid, path = match.groups()
                self.binary_images[lib_name] = {
                    'start_addr': start_addr,
                    'end_addr': end_addr,
                    'uuid': uuid,
                    'path': path
                }
    
    def find_dsym_file(self, lib_name):
        """查找对应的dSYM文件"""
        dsym_path = Path(self.dsym_path)
        
        # 如果输入的是.dSYM目录
        if dsym_path.suffix == '.dSYM':
            dwarf_dir = dsym_path / 'Contents' / 'Resources' / 'DWARF'
            if dwarf_dir.exists():
                # 查找对应的DWARF文件
                for dwarf_file in dwarf_dir.iterdir():
                    if lib_name in dwarf_file.name or dwarf_file.name == lib_name:
                        return str(dwarf_file)
        
        # 如果输入的是包含dSYM的目录
        elif dsym_path.is_dir():
            for dsym_dir in dsym_path.rglob('*.dSYM'):
                dwarf_dir = dsym_dir / 'Contents' / 'Resources' / 'DWARF'
                if dwarf_dir.exists():
                    for dwarf_file in dwarf_dir.iterdir():
                        if lib_name in dwarf_file.name or dwarf_file.name == lib_name:
                            return str(dwarf_file)
        
        return None
    
    def symbolicate_address(self, lib_name, address, load_address):
        """使用atos符号化单个地址"""
        # 查找对应的dSYM文件
        dsym_file = self.find_dsym_file(lib_name)
        if not dsym_file:
            return None
            
        try:
            cmd = [
                'atos',
                '-arch', 'arm64',
                '-o', dsym_file,
                '-l', load_address,
                address
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                symbol = result.stdout.strip()
                # 如果返回的是地址，说明没有找到符号
                if symbol.startswith('0x'):
                    return None
                return symbol
        except Exception:
            pass
        
        return None
    
    def symbolicate_stack_line(self, line):
        """符号化单行堆栈信息"""
        # 匹配格式: 帧号 库名 地址 基址 + 偏移
        pattern = r'(\d+)\s+([^\s]+)\s+(0x[a-f0-9]+)\s+(0x[a-f0-9]+)\s+\+\s+(\d+)'
        match = re.match(pattern, line.strip())
        
        if not match:
            return line
            
        frame_num, lib_name, address, base_addr, offset = match.groups()
        
        # 只符号化我们关心的库
        if lib_name in self.binary_images:
            load_addr = self.binary_images[lib_name]['start_addr']
            symbol = self.symbolicate_address(lib_name, address, load_addr)
            
            if symbol:
                # 保持官方格式: 帧号 库名 地址 基址 + 偏移 符号信息
                # 精确匹配官方symbolicatecrash的格式
                return f"{frame_num:<3} {lib_name:<35} {address} {base_addr} + {offset} {symbol}"
        
        return line
    
    def process_crash_file(self):
        """处理整个crash文件"""
        try:
            with open(self.crash_file, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            print(f"❌ 无法读取crash文件: {e}")
            return False
            
        # 解析Binary Images
        self.parse_binary_images(content)
        
        # 处理每一行
        lines = content.split('\n')
        in_thread_section = False
        
        for line in lines:
            # 检测是否进入线程堆栈部分
            if re.match(r'Thread \d+.*:', line):
                in_thread_section = True
                self.symbolicated_lines.append(line)
                continue
            elif line.startswith('Binary Images:'):
                in_thread_section = False
                self.symbolicated_lines.append(line)
                continue
            elif not line.strip():
                in_thread_section = False
                self.symbolicated_lines.append(line)
                continue
                
            # 如果在线程部分，尝试符号化
            if in_thread_section and re.match(r'\d+\s+', line.strip()):
                symbolicated_line = self.symbolicate_stack_line(line)
                self.symbolicated_lines.append(symbolicated_line)
            else:
                self.symbolicated_lines.append(line)
        
        return True
    
    def save_result(self, output_file=None):
        """保存符号化结果"""
        if output_file is None:
            output_file = self.crash_file.replace('.crash', '_symbolicated.crash')
            
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write('\n'.join(self.symbolicated_lines))
            print(f"✅ 符号化结果已保存到: {output_file}")
            return output_file
        except Exception as e:
            print(f"❌ 保存文件失败: {e}")
            return None
    
    def print_result(self):
        """打印符号化结果"""
        print("🔧 符号化结果:")
        print("=" * 80)
        
        for line in self.symbolicated_lines:
            print(line)

def main():
    if len(sys.argv) != 3:
        print("用法: python3 crash_symbolicate.py <crash.log> <dsym_path>")
        print("")
        print("参数说明:")
        print("  crash.log  - crash文件路径")
        print("  dsym_path  - dSYM文件或目录路径")
        print("")
        print("示例:")
        print("  python3 crash_symbolicate.py 11.crash /path/to/app.dSYM")
        print("  python3 crash_symbolicate.py 11.crash /path/to/derived_data/")
        sys.exit(1)
    
    crash_file = sys.argv[1]
    dsym_path = sys.argv[2]
    
    # 检查文件是否存在
    if not os.path.exists(crash_file):
        print(f"❌ Crash文件不存在: {crash_file}")
        sys.exit(1)
        
    if not os.path.exists(dsym_path):
        print(f"❌ dSYM路径不存在: {dsym_path}")
        sys.exit(1)
    
    print(f"🚀 开始符号化crash文件...")
    print(f"📁 Crash文件: {crash_file}")
    print(f"📁 dSYM路径: {dsym_path}")
    print("=" * 80)
    
    # 创建符号化器并处理
    symbolicator = CrashSymbolicator(crash_file, dsym_path)
    
    if symbolicator.process_crash_file():
        # 保存结果
        output_file = symbolicator.save_result()
        
        # 显示统计信息
        total_images = len(symbolicator.binary_images)
        print(f"📊 解析到 {total_images} 个二进制镜像")
        
        # 显示关键库信息
        app_libs = [name for name in symbolicator.binary_images.keys() 
                   if not name.startswith('lib') and not name.startswith('/')]
        if app_libs:
            print(f"🎯 应用相关库: {', '.join(app_libs)}")
        
        print("\n💡 如需查看完整符号化结果:")
        print(f"   cat {output_file}")
        
    else:
        print("❌ 符号化失败")
        sys.exit(1)

if __name__ == "__main__":
    main()
