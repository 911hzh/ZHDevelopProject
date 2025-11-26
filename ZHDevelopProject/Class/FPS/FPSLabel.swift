//
//  FPSLabel.swift
//  NewDesign
//
//  Created by huang on 2025/4/2.
//  Copyright © 2025 huang. All rights reserved.
//

import Foundation
import UIKit

class FPSLabel: UILabel {
    // 用于存储 DisplayLink
    private var displayLink: CADisplayLink?
    // 记录上一次的时间戳
    private var lastTimestamp: CFTimeInterval = 0
    // 计数器，用于计算帧率
    private var count: Int = 0
    
    // 初始化方法
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // 设置基本UI属性
        layer.cornerRadius = 5
        layer.masksToBounds = true
        textAlignment = .center
        backgroundColor = UIColor.black.withAlphaComponent(0.7)
        textColor = .white
        font = .systemFont(ofSize: 14)
        
        // 设置默认frame
        frame = CGRect(x: 0, y: 0, width: 80, height: 30)
    }
    
    // 显示FPS监控器
    public static func showFPS(in parentView: UIView? = nil) -> FPSLabel {
        let fpsLabel = FPSLabel()
        
        // 确定父视图
        let targetView = parentView ?? UIApplication.shared.windows.first
        
        if let view = targetView {
            // 设置位置到右上角
            fpsLabel.frame.origin = CGPoint(
                x: view.bounds.width - fpsLabel.frame.width - 20,
                y: 50
            )
            view.addSubview(fpsLabel)
            fpsLabel.startMonitoring()
        }
        
        return fpsLabel
    }
    
    // 隐藏FPS监控器
    public func hide() {
        stopMonitoring()
        removeFromSuperview()
    }
    
    // 开始监控FPS
    public func startMonitoring() {
        stopMonitoring() // 确保之前的监控被停止
        
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    // 停止监控FPS
    public func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        text = "0 FPS"
    }
    
    @objc private func displayLinkTick(link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        
        count += 1
        let delta = link.timestamp - lastTimestamp
        
        // 每隔1秒更新一次FPS
        if delta >= 1.0 {
            let fps = Int(round(Double(count) / delta))
            text = "\(fps) FPS"
            print("----fps: \(fps)")
            count = 0
            lastTimestamp = link.timestamp
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
