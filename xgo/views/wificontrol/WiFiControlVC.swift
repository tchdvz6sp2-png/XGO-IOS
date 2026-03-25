//
//  WiFiControlVC.swift
//  xgo
//
//  WiFi remote control for XGO Rider via SocketIO
//  Features: virtual joystick, action buttons, height slider, camera preview
//

import UIKit

class WiFiControlVC: UIViewController {
    
    // MARK: - UI Elements
    private let backButton = UIButton(type: .system)
    private let connectionLabel = UILabel()
    private let ipField = UITextField()
    private let connectButton = UIButton(type: .system)
    
    // Joystick area
    private let joystickContainer = UIView()
    private let joystickThumb = UIView()
    private var joystickCenter: CGPoint = .zero
    private let joystickRadius: CGFloat = 60
    
    // Action buttons
    private let actionStack = UIStackView()
    private let resetButton = UIButton(type: .system)
    private let balanceButton = UIButton(type: .system)
    
    // Height slider
    private let heightSlider = UISlider()
    private let heightLabel = UILabel()
    
    // Camera preview (small pip)
    private let cameraPreview = MJPEGStreamView(frame: .zero)
    
    // State
    private var isBalanceOn = false
    private var moveTimer: Timer?
    private var currentMoveX: Int = 128  // neutral
    private var currentTurn: Int = 128   // neutral
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 1)
        setupUI()
        setupWiFiCallbacks()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        moveTimer?.invalidate()
        cameraPreview.stopStream()
        WiFiManager.shared.stopMovement()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Back button
        backButton.setTitle(NSLocalizedString("general.back", comment: ""), for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
        
        // IP field
        ipField.placeholder = "192.168.4.1"
        ipField.text = WiFiManager.shared.host
        ipField.textColor = .white
        ipField.backgroundColor = UIColor(white: 0.15, alpha: 1)
        ipField.layer.cornerRadius = 6
        ipField.textAlignment = .center
        ipField.keyboardType = .decimalPad
        ipField.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        view.addSubview(ipField)
        
        // Connect button
        connectButton.setTitle(NSLocalizedString("wifi.connect", comment: ""), for: .normal)
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.backgroundColor = UIColor(red: 0, green: 0.6, blue: 0.3, alpha: 1)
        connectButton.layer.cornerRadius = 6
        connectButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        view.addSubview(connectButton)
        
        // Connection status
        connectionLabel.text = NSLocalizedString("wifi.disconnected", comment: "")
        connectionLabel.textColor = .lightGray
        connectionLabel.font = UIFont.systemFont(ofSize: 12)
        connectionLabel.textAlignment = .center
        view.addSubview(connectionLabel)
        
        // Joystick
        setupJoystick()
        
        // Action buttons on the right side
        setupActionButtons()
        
        // Height slider at bottom
        setupHeightSlider()
        
        // Camera preview (picture-in-picture, top right)
        cameraPreview.layer.cornerRadius = 8
        cameraPreview.layer.borderColor = UIColor.gray.cgColor
        cameraPreview.layer.borderWidth = 1
        cameraPreview.clipsToBounds = true
        view.addSubview(cameraPreview)
        
        layoutUI()
    }
    
    private func setupJoystick() {
        joystickContainer.backgroundColor = UIColor(white: 0.12, alpha: 1)
        joystickContainer.layer.cornerRadius = joystickRadius + 20
        joystickContainer.layer.borderColor = UIColor(white: 0.3, alpha: 1).cgColor
        joystickContainer.layer.borderWidth = 2
        view.addSubview(joystickContainer)
        
        joystickThumb.backgroundColor = UIColor(red: 0, green: 0.7, blue: 1, alpha: 0.9)
        joystickThumb.layer.cornerRadius = 25
        joystickThumb.frame.size = CGSize(width: 50, height: 50)
        joystickContainer.addSubview(joystickThumb)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(joystickPanned(_:)))
        joystickContainer.addGestureRecognizer(pan)
    }
    
    private func setupActionButtons() {
        // Reset button
        resetButton.setTitle(NSLocalizedString("general.reset", comment: ""), for: .normal)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        resetButton.layer.cornerRadius = 8
        resetButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        
        // Balance button
        balanceButton.setTitle(NSLocalizedString("dashboard.balance_off", comment: ""), for: .normal)
        balanceButton.setTitleColor(.white, for: .normal)
        balanceButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        balanceButton.layer.cornerRadius = 8
        balanceButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        balanceButton.addTarget(self, action: #selector(balanceTapped), for: .touchUpInside)
        
        // Action 1-4 quick buttons
        let actions = [
            (NSLocalizedString("action.spin", comment: ""), 4),
            (NSLocalizedString("action.wave_hand", comment: ""), 13),
            (NSLocalizedString("action.dance1", comment: ""), 21),
            (NSLocalizedString("action.balance_demo", comment: ""), 23)
        ]
        
        actionStack.axis = .vertical
        actionStack.spacing = 8
        actionStack.distribution = .fillEqually
        actionStack.addArrangedSubview(resetButton)
        actionStack.addArrangedSubview(balanceButton)
        
        for (title, actionNum) in actions {
            let btn = UIButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = UIColor(red: 0.15, green: 0.25, blue: 0.4, alpha: 1)
            btn.layer.cornerRadius = 8
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            btn.tag = actionNum
            btn.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
            actionStack.addArrangedSubview(btn)
        }
        
        view.addSubview(actionStack)
    }
    
    private func setupHeightSlider() {
        heightLabel.text = NSLocalizedString("general.height", comment: "")
        heightLabel.textColor = .lightGray
        heightLabel.font = UIFont.systemFont(ofSize: 12)
        view.addSubview(heightLabel)
        
        heightSlider.minimumValue = 0
        heightSlider.maximumValue = 100
        heightSlider.value = 50
        heightSlider.minimumTrackTintColor = UIColor(red: 0, green: 0.7, blue: 1, alpha: 1)
        heightSlider.addTarget(self, action: #selector(heightChanged(_:)), for: .valueChanged)
        view.addSubview(heightSlider)
    }
    
    private func layoutUI() {
        // Use manual frames for landscape layout
        let safeLeft: CGFloat = 60
        let safeTop: CGFloat = 20
        
        backButton.frame = CGRect(x: safeLeft, y: safeTop, width: 60, height: 30)
        ipField.frame = CGRect(x: safeLeft + 70, y: safeTop, width: 160, height: 30)
        connectButton.frame = CGRect(x: safeLeft + 240, y: safeTop, width: 90, height: 30)
        connectionLabel.frame = CGRect(x: safeLeft + 340, y: safeTop, width: 120, height: 30)
        
        // Joystick - left side
        let joySize: CGFloat = (joystickRadius + 20) * 2
        let joyY = SCREEN_HEIGHT / 2 - joySize / 2 + 10
        joystickContainer.frame = CGRect(x: safeLeft + 20, y: joyY, width: joySize, height: joySize)
        joystickCenter = CGPoint(x: joySize / 2, y: joySize / 2)
        joystickThumb.center = joystickCenter
        
        // Action buttons - right side
        let actionWidth: CGFloat = 110
        let actionX = SCREEN_WIDTH - safeLeft - actionWidth - 10
        actionStack.frame = CGRect(x: actionX, y: safeTop + 40, width: actionWidth, height: SCREEN_HEIGHT - safeTop - 80)
        
        // Camera preview - center-top
        let previewWidth: CGFloat = 200
        let previewHeight: CGFloat = 150
        let previewX = (SCREEN_WIDTH - previewWidth) / 2
        cameraPreview.frame = CGRect(x: previewX, y: safeTop + 40, width: previewWidth, height: previewHeight)
        
        // Height slider - bottom center
        let sliderWidth: CGFloat = 250
        heightLabel.frame = CGRect(x: (SCREEN_WIDTH - sliderWidth) / 2 - 60, y: SCREEN_HEIGHT - 50, width: 55, height: 30)
        heightSlider.frame = CGRect(x: (SCREEN_WIDTH - sliderWidth) / 2, y: SCREEN_HEIGHT - 50, width: sliderWidth, height: 30)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutUI()
    }
    
    // MARK: - WiFi Callbacks
    
    private func setupWiFiCallbacks() {
        WiFiManager.shared.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .disconnected:
                    self?.connectionLabel.text = NSLocalizedString("wifi.disconnected", comment: "")
                    self?.connectionLabel.textColor = .lightGray
                    self?.connectButton.backgroundColor = UIColor(red: 0, green: 0.6, blue: 0.3, alpha: 1)
                    self?.connectButton.setTitle(NSLocalizedString("wifi.connect", comment: ""), for: .normal)
                case .connecting:
                    self?.connectionLabel.text = NSLocalizedString("wifi.connecting", comment: "")
                    self?.connectionLabel.textColor = .yellow
                case .connected:
                    self?.connectionLabel.text = NSLocalizedString("wifi.connected", comment: "")
                    self?.connectionLabel.textColor = .green
                    self?.connectButton.backgroundColor = UIColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 1)
                    self?.connectButton.setTitle(NSLocalizedString("wifi.disconnect", comment: ""), for: .normal)
                    // Start camera preview
                    if let url = WiFiManager.shared.videoStreamURL {
                        self?.cameraPreview.startStream(url: url)
                    }
                }
            }
        }
    }
    
    // MARK: - Joystick Handling
    
    @objc private func joystickPanned(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: joystickContainer)
        
        switch gesture.state {
        case .began, .changed:
            // Clamp to circle
            let dx = location.x - joystickCenter.x
            let dy = location.y - joystickCenter.y
            let distance = sqrt(dx * dx + dy * dy)
            
            var thumbPos: CGPoint
            if distance <= joystickRadius {
                thumbPos = location
            } else {
                let angle = atan2(dy, dx)
                thumbPos = CGPoint(
                    x: joystickCenter.x + joystickRadius * cos(angle),
                    y: joystickCenter.y + joystickRadius * sin(angle)
                )
            }
            joystickThumb.center = thumbPos
            
            // Map to speed values (0-255, 128=neutral)
            let normX = (thumbPos.x - joystickCenter.x) / joystickRadius  // -1 to 1
            let normY = (thumbPos.y - joystickCenter.y) / joystickRadius  // -1 to 1 (inverted)
            
            currentMoveX = 128 - Int(normY * 127)  // up = forward
            currentTurn = 128 + Int(normX * 127)    // right = turn right
            
            startMoveTimer()
            
        case .ended, .cancelled:
            // Spring back
            UIView.animate(withDuration: 0.2) {
                self.joystickThumb.center = self.joystickCenter
            }
            currentMoveX = 128
            currentTurn = 128
            WiFiManager.shared.stopMovement()
            moveTimer?.invalidate()
            moveTimer = nil
            
        default:
            break
        }
    }
    
    private func startMoveTimer() {
        guard moveTimer == nil else { return }
        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.currentMoveX != 128 {
                if self.currentMoveX > 128 {
                    WiFiManager.shared.moveForward(speed: self.currentMoveX)
                } else {
                    WiFiManager.shared.moveBackward(speed: self.currentMoveX)
                }
            }
            if self.currentTurn != 128 {
                if self.currentTurn > 128 {
                    WiFiManager.shared.turnRight(speed: self.currentTurn)
                } else {
                    WiFiManager.shared.turnLeft(speed: self.currentTurn)
                }
            }
        }
    }
    
    // MARK: - Button Actions
    
    @objc private func backTapped() {
        WiFiManager.shared.stopMovement()
        cameraPreview.stopStream()
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func connectTapped() {
        view.endEditing(true)
        if WiFiManager.shared.state == .connected {
            WiFiManager.shared.disconnect()
            cameraPreview.stopStream()
        } else {
            let ip = ipField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "192.168.4.1"
            WiFiManager.shared.connect(host: ip)
        }
    }
    
    @objc private func resetTapped() {
        WiFiManager.shared.reset()
    }
    
    @objc private func balanceTapped() {
        isBalanceOn.toggle()
        WiFiManager.shared.setBalance(enabled: isBalanceOn)
        balanceButton.setTitle(
            isBalanceOn
                ? NSLocalizedString("dashboard.balance_on", comment: "")
                : NSLocalizedString("dashboard.balance_off", comment: ""),
            for: .normal
        )
        balanceButton.backgroundColor = isBalanceOn
            ? UIColor(red: 0, green: 0.5, blue: 0.3, alpha: 1)
            : UIColor(white: 0.25, alpha: 1)
    }
    
    @objc private func actionTapped(_ sender: UIButton) {
        WiFiManager.shared.performAction(number: sender.tag)
    }
    
    @objc private func heightChanged(_ slider: UISlider) {
        WiFiManager.shared.setHeight(value: Int(slider.value))
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
}
