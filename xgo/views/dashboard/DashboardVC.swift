//
//  DashboardVC.swift
//  xgo
//
//  XGO Robot Dashboard - Battery, IMU, Self-Balance toggle
//

import UIKit

class DashboardVC: UIViewController {
    
    // MARK: - UI Elements
    private let batteryLabel = UILabel()
    private let batteryBar = UIProgressView(progressViewStyle: .default)
    private let firmwareLabel = UILabel()
    private let rollLabel = UILabel()
    private let pitchLabel = UILabel()
    private let yawLabel = UILabel()
    private let balanceSwitch = UISwitch()
    private let balanceLabel = UILabel()
    private let backButton = UIButton(type: .system)
    
    private var refreshTimer: Timer?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 23/255, green: 23/255, blue: 27/255, alpha: 1.0)
        setupUI()
        readInitialData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh IMU data every 1 second
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshIMUData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "Dashboard"
        titleLabel.textColor = UIColor(red: 0, green: 223/255, blue: 250/255, alpha: 1.0)
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Back button
        backButton.setTitle(NSLocalizedString("general.back", comment: "Back"), for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(onBackTap), for: .touchUpInside)
        view.addSubview(backButton)
        
        // Battery section
        let batteryTitle = makeLabel(text: NSLocalizedString("dashboard.battery", comment: "Battery"), size: 16, color: .lightGray)
        view.addSubview(batteryTitle)
        
        batteryLabel.text = "-- %"
        batteryLabel.textColor = .white
        batteryLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 28, weight: .bold)
        batteryLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(batteryLabel)
        
        batteryBar.progressTintColor = UIColor(red: 39/255, green: 233/255, blue: 158/255, alpha: 1.0)
        batteryBar.trackTintColor = UIColor.darkGray
        batteryBar.translatesAutoresizingMaskIntoConstraints = false
        batteryBar.layer.cornerRadius = 4
        batteryBar.clipsToBounds = true
        view.addSubview(batteryBar)
        
        // Firmware
        let fwTitle = makeLabel(text: NSLocalizedString("dashboard.firmware", comment: "Firmware"), size: 16, color: .lightGray)
        view.addSubview(fwTitle)
        
        firmwareLabel.text = "--"
        firmwareLabel.textColor = .white
        firmwareLabel.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .medium)
        firmwareLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(firmwareLabel)
        
        // IMU section
        let imuTitle = makeLabel(text: "IMU", size: 16, color: .lightGray)
        view.addSubview(imuTitle)
        
        rollLabel.text = NSLocalizedString("dashboard.imu_roll", comment: "Roll") + ": --\u{00B0}"
        rollLabel.textColor = .white
        rollLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
        rollLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rollLabel)
        
        pitchLabel.text = NSLocalizedString("dashboard.imu_pitch", comment: "Pitch") + ": --\u{00B0}"
        pitchLabel.textColor = .white
        pitchLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
        pitchLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pitchLabel)
        
        yawLabel.text = NSLocalizedString("dashboard.imu_yaw", comment: "Yaw") + ": --\u{00B0}"
        yawLabel.textColor = .white
        yawLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
        yawLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(yawLabel)
        
        // Balance switch
        balanceLabel.text = NSLocalizedString("dashboard.balance", comment: "Self-Balance")
        balanceLabel.textColor = .white
        balanceLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(balanceLabel)
        
        balanceSwitch.onTintColor = UIColor(red: 0, green: 223/255, blue: 250/255, alpha: 1.0)
        balanceSwitch.isOn = false
        balanceSwitch.translatesAutoresizingMaskIntoConstraints = false
        balanceSwitch.addTarget(self, action: #selector(onBalanceToggle(_:)), for: .valueChanged)
        view.addSubview(balanceSwitch)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Back button - top left
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Battery title
            batteryTitle.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            batteryTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Battery value
            batteryLabel.topAnchor.constraint(equalTo: batteryTitle.bottomAnchor, constant: 4),
            batteryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Battery bar
            batteryBar.topAnchor.constraint(equalTo: batteryLabel.bottomAnchor, constant: 6),
            batteryBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            batteryBar.widthAnchor.constraint(equalToConstant: 140),
            batteryBar.heightAnchor.constraint(equalToConstant: 8),
            
            // Firmware title
            fwTitle.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            fwTitle.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10),
            
            // Firmware value
            firmwareLabel.topAnchor.constraint(equalTo: fwTitle.bottomAnchor, constant: 4),
            firmwareLabel.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10),
            
            // IMU title
            imuTitle.topAnchor.constraint(equalTo: batteryBar.bottomAnchor, constant: 18),
            imuTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Roll / Pitch / Yaw - horizontal
            rollLabel.topAnchor.constraint(equalTo: imuTitle.bottomAnchor, constant: 6),
            rollLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            pitchLabel.topAnchor.constraint(equalTo: imuTitle.bottomAnchor, constant: 6),
            pitchLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            yawLabel.topAnchor.constraint(equalTo: imuTitle.bottomAnchor, constant: 6),
            yawLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Balance switch
            balanceLabel.topAnchor.constraint(equalTo: rollLabel.bottomAnchor, constant: 20),
            balanceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            balanceSwitch.centerYAnchor.constraint(equalTo: balanceLabel.centerYAnchor),
            balanceSwitch.leadingAnchor.constraint(equalTo: balanceLabel.trailingAnchor, constant: 12),
        ])
    }
    
    private func makeLabel(text: String, size: CGFloat, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = UIFont.systemFont(ofSize: size)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    // MARK: - Data
    private func readInitialData() {
        // Read battery
        FindControlUtil.readBattery { [weak self] data in
            guard let self = self, data.count > 0 else { return }
            let battery = Int(data[0])
            DispatchQueue.main.async {
                self.batteryLabel.text = "\(battery) %"
                self.batteryBar.progress = Float(battery) / 100.0
                if battery < 20 {
                    self.batteryBar.progressTintColor = .red
                } else if battery < 50 {
                    self.batteryBar.progressTintColor = .orange
                } else {
                    self.batteryBar.progressTintColor = UIColor(red: 39/255, green: 233/255, blue: 158/255, alpha: 1.0)
                }
            }
        }
        
        // Read firmware version
        FindControlUtil.readVersion { [weak self] data in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if data.count > 0 {
                    let version: String
                    switch data[0] {
                    case 0x00: version = "XGO Mini"
                    case 0x01: version = "XGO Lite"
                    case 0x02: version = "XGO Pro"
                    default:
                        // Try to decode as ASCII string
                        let filtered = data.filter { $0 != 0 }
                        version = String(bytes: filtered, encoding: .ascii) ?? "v\(data[0])"
                    }
                    self.firmwareLabel.text = version
                }
            }
        }
    }
    
    private func refreshIMUData() {
        guard BLEMANAGER?.isConnect() == true else { return }
        
        FindControlUtil.readRoll { [weak self] data in
            guard let self = self, data.count >= 4 else { return }
            let value = self.bytesToFloat(data)
            DispatchQueue.main.async {
                self.rollLabel.text = String(format: "%@: %.1f\u{00B0}",
                    NSLocalizedString("dashboard.imu_roll", comment: ""), value)
            }
        }
        
        FindControlUtil.readPitch { [weak self] data in
            guard let self = self, data.count >= 4 else { return }
            let value = self.bytesToFloat(data)
            DispatchQueue.main.async {
                self.pitchLabel.text = String(format: "%@: %.1f\u{00B0}",
                    NSLocalizedString("dashboard.imu_pitch", comment: ""), value)
            }
        }
        
        FindControlUtil.readYaw { [weak self] data in
            guard let self = self, data.count >= 4 else { return }
            let value = self.bytesToFloat(data)
            DispatchQueue.main.async {
                self.yawLabel.text = String(format: "%@: %.1f\u{00B0}",
                    NSLocalizedString("dashboard.imu_yaw", comment: ""), value)
            }
        }
    }
    
    /// Convert 4 bytes (big-endian) to Float
    private func bytesToFloat(_ data: [UInt8]) -> Float {
        guard data.count >= 4 else { return 0 }
        var bytes = Data()
        bytes.append(data[3])
        bytes.append(data[2])
        bytes.append(data[1])
        bytes.append(data[0])
        return bytes.withUnsafeBytes { $0.load(as: Float.self) }
    }
    
    // MARK: - Actions
    @objc private func onBalanceToggle(_ sender: UISwitch) {
        FindControlUtil.setIMUBalance(enabled: sender.isOn)
        let msg = sender.isOn
            ? NSLocalizedString("dashboard.balance_on", comment: "")
            : NSLocalizedString("dashboard.balance_off", comment: "")
        CBToast.showToastAction(message: msg as NSString)
    }
    
    @objc private func onBackTap() {
        self.navigationController?.popViewController(animated: true)
    }
}
