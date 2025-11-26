//
//  FPSViewController.swift
//  ZHDevelopProject
//
//  Created by huang on 2025/9/16.
//

import Foundation
import UIKit
class FPSViewController: UIViewController {
    
    @IBOutlet weak var runloopButton: UIButton!
    
    @IBOutlet weak var fpsButton: UIButton!
    
    @IBOutlet weak var beginLaggyButton: UIButton!
    
    private var stutterTimer: Timer?
    
    private var fpsLabel: FPSLabel?
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    init() {
        super.init(nibName: "FPSViewController", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        fpsButton.setTitleColor(UIColor.blue, for: UIControl.State.normal)
        fpsButton.setTitleColor(UIColor.red, for: UIControl.State.selected)
        
        runloopButton.setTitleColor(UIColor.blue, for: UIControl.State.normal)
        runloopButton.setTitleColor(UIColor.red, for: UIControl.State.selected)
        
        beginLaggyButton.setTitleColor(UIColor.blue, for: UIControl.State.normal)
        beginLaggyButton.setTitleColor(UIColor.red, for: UIControl.State.selected)
        
        beginLaggyButton.setTitle("begin Laggy", for: UIControl.State.normal)
        beginLaggyButton.setTitle("end Laggy", for: UIControl.State.selected)
        
        fpsButton.setTitle("show fps", for: UIControl.State.normal)
        fpsButton.setTitle("hide fps", for: UIControl.State.selected)
        
        runloopButton.setTitle("begin runloop", for: UIControl.State.normal)
        runloopButton.setTitle("end runloop", for: UIControl.State.selected)
    }
    
    @IBAction func tapFps(_ sender: Any) {
        fpsButton.isSelected = !fpsButton.isSelected
        if fpsButton.isSelected {
            fpsLabel = FPSLabel.showFPS(in: view)
        } else {
            fpsLabel?.hide()
        }
    }
    
    @IBAction func tapRunloop(_ sender: Any) {
        runloopButton.isSelected = !runloopButton.isSelected
        if runloopButton.isSelected {
            RunLoopMonitor.shared.start()
            return
        }
        RunLoopMonitor.shared.stop()
        
    }
    @IBAction func tapBeginLaggy(_ sender: Any) {
        beginLaggyButton.isSelected = !beginLaggyButton.isSelected
        if beginLaggyButton.isSelected {
            startStutter()
            return
        }
        stopStutter()
    }
    deinit {
        fpsLabel?.hide()
        RunLoopMonitor.shared.stop()
        stopStutter()
    }
    private func startStutter() {
        // 创建定时器，每200ms触发一次
        stutterTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            // 模拟卡顿 300ms
            Thread.sleep(forTimeInterval: 0.3)
        }
    }
    @objc private func stopStutter() {
        stutterTimer?.invalidate()
        stutterTimer = nil
    }
}
