//
//  ViewController.swift
//  PerformaceMonitor
//
//  Created by huang on 2025/9/16.
//

import UIKit
class ViewController: UIViewController {
    private var viewControllersString: [String] = ["FPSViewController"]
    private lazy var tableView: UITableView = {
        let view = UITableView()
        view.delegate = self
        view.dataSource = self
        view.register(UITableViewCell.classForCoder(), forCellReuseIdentifier: "UITableViewCell")
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.reloadData()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        
        // Do any additional setup after loading the view.
    }
}
extension ViewController:  UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewControllersString.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.text = viewControllersString[indexPath.row]
        cell.contentConfiguration = configuration
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let vcClassString = viewControllersString[indexPath.row]
        
        guard let classType = NSClassFromString("ZHDevelopProject.\(vcClassString)") else {
            fatalError()
        }
        guard let VC = classType as? UIViewController.Type else {
            fatalError()
        }
        
        navigationController?.pushViewController(VC.init(), animated: true)
    }

    
}

