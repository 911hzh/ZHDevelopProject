//
//  RunloopFPS.swift
//  NewDesign
//
//  Created by huang on 2025/4/2.
//  Copyright © 2025 huang. All rights reserved.
//

import Foundation
import QuartzCore
import CrashReporter
fileprivate func printLog<T>(
    _ message: T,
    error: Bool = false,
    file: String = #file,
    method: String = #function,
    line: Int = #line
) {
    if error {
        let file = (file as NSString).lastPathComponent;
        // 文件名：行数---要打印的信息
        print("error: \(file):(\(line))--\(message)");
    }
    
}
class RunLoopMonitor {
    // 单例
    static let shared = RunLoopMonitor()
    // MARK: -公开属性
    /**
     超时多少毫秒算卡顿
     */
    public var timeOutMillSeconds: Int = 30
    /**
     连续超时了多少次才会计入耗时
     */
    public var timeoutMaxCount = 5
    
    // MARK: -私有属性
    /**
     当前已经超时了几次
     */
    private var currentTimeoutCount = 0
    
    
    // 监控线程
    private var observer: CFRunLoopObserver?
    
    // 信号量
    private var semaphore: DispatchSemaphore?
    
    // 记录RunLoop的状态
    private var activity: CFRunLoopActivity = .entry
    
    
    
    private init() {}
    
    // 开始监控
    func start() {
        guard observer == nil else { return }
        
        // 创建信号量
        semaphore = DispatchSemaphore(value: 0)
//        print("dispatch_semaphore_create: \(getCurrentTime())")
        
        // 创建 observer context
        var context = CFRunLoopObserverContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        // 创建 Observer
        observer = CFRunLoopObserverCreate(
            kCFAllocatorDefault,
            CFRunLoopActivity.allActivities.rawValue,
            true,
            0,
            { observer, activity, info in
                guard let info = info else { return }
                let monitor = Unmanaged<RunLoopMonitor>.fromOpaque(info).takeUnretainedValue()
                monitor.runLoopObserverCallback(observer: observer, activity: activity)
            },
            &context
        )
        
        // 添加 Observer 到主线程 RunLoop
        if let observer = observer {
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        }
        
        // 在子线程监控时长
        DispatchQueue.global().async { [weak self] in
            while true {
                guard let self = self else { return }
                
                // 等待信号量,超时时间50ms
                let status = self.semaphore?.wait(timeout: .now() + .milliseconds(self.timeOutMillSeconds))
                if status == .timedOut {  // 超时
                    if self.observer == nil {
                        self.currentTimeoutCount = 0
                        self.semaphore = nil
                        self.activity = .entry
                        return
                    }
                    
                    // 检查是否在 beforeSources 或 afterWaiting 状态
                    if self.activity == .beforeSources || self.activity == .afterWaiting {
                        self.currentTimeoutCount += 1
                        if self.currentTimeoutCount < self.timeoutMaxCount {
                            continue
                        }
                        
                        // 使用PLCrashReporter获取主线程堆栈信息
                        printLog("---------检测到卡顿---------")
                        self.printStackTrace()
                        
                    }
                }
                
//                print("dispatch_semaphore_wait currentTimeoutCount = 0, time:\(self.getCurrentTime())")
                self.currentTimeoutCount = 0
            }
        }
    }
    
    // 停止监控
    func stop() {
        if let observer = observer {
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
            self.observer = nil
        }
    }
    
    private func runLoopObserverCallback(observer: CFRunLoopObserver?, activity: CFRunLoopActivity) {
        // 记录状态
        self.activity = activity
        
        // 发送信号
        if let signal = semaphore?.signal() {
            printLog("dispatch_semaphore_signal: signal=\(signal), time:\(getCurrentTime())")
        }
        
        // 打印RunLoop状态
        switch activity {
        case .entry:
            printLog("runLoopObserverCallback - kCFRunLoopEntry")
        case .beforeTimers:
            printLog("runLoopObserverCallback - kCFRunLoopBeforeTimers")
        case .beforeSources:
            printLog("runLoopObserverCallback - kCFRunLoopBeforeSources")
        case .beforeWaiting:
            printLog("runLoopObserverCallback - kCFRunLoopBeforeWaiting")
        case .afterWaiting:
            printLog("runLoopObserverCallback - kCFRunLoopAfterWaiting")
        case .exit:
            printLog("runLoopObserverCallback - kCFRunLoopExit")
        default:
            printLog("runLoopObserverCallback - kCFRunLoopAllActivities")
        }
    }
    
    private func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    // 使用PLCrashReporter打印主线程堆栈信息
    private func printStackTrace() {
        guard let reporter = PLCrashReporter(configuration: PLCrashReporterConfig.defaultConfiguration()) else {
            printLog("❌ 无法创建PLCrashReporter实例", error: true)
//            printSystemStackTrace()
            return
        }
        
        do {
            // 生成实时报告
            let liveReportData = reporter.generateLiveReport()
            let report = try PLCrashReport(data: liveReportData)
            
            // 使用PLCrashReporter的内置格式化器
            print("******begin***********\n\n")
            let formattedReport = PLCrashReportTextFormatter.stringValue(for: report, with: PLCrashReportTextFormatiOS) ?? ""
            print(formattedReport)
            print("\n\n******end**********\n\n")
            
        } catch {
            print("❌ PLCrashReporter生成报告失败: \(error)")
        }
    }
}

