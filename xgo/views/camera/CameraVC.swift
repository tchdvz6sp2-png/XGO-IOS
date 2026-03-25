//
//  CameraVC.swift
//  xgo
//
//  Live camera view from XGO Rider CM4 (MJPEG stream)
//

import UIKit

class CameraVC: UIViewController {
    
    private let streamView = MJPEGStreamView(frame: .zero)
    private let statusLabel = UILabel()
    private let connectButton = UIButton(type: .system)
    private let ipField = UITextField()
    private let backButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        streamView.stopStream()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Back button
        backButton.setTitle(NSLocalizedString("general.back", comment: ""), for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Stream view (main area)
        streamView.contentMode = .scaleAspectFit
        streamView.backgroundColor = .black
        view.addSubview(streamView)
        streamView.translatesAutoresizingMaskIntoConstraints = false
        
        // Status label
        statusLabel.text = NSLocalizedString("camera.disconnected", comment: "")
        statusLabel.textColor = .lightGray
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // IP input field
        ipField.placeholder = "192.168.4.1"
        ipField.text = WiFiManager.shared.host
        ipField.textColor = .white
        ipField.backgroundColor = UIColor(white: 0.15, alpha: 1)
        ipField.layer.cornerRadius = 8
        ipField.textAlignment = .center
        ipField.keyboardType = .decimalPad
        ipField.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .medium)
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        ipField.leftView = paddingView
        ipField.leftViewMode = .always
        view.addSubview(ipField)
        ipField.translatesAutoresizingMaskIntoConstraints = false
        
        // Connect button
        connectButton.setTitle(NSLocalizedString("camera.connect", comment: ""), for: .normal)
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.backgroundColor = UIColor(red: 0, green: 0.6, blue: 0.9, alpha: 1)
        connectButton.layer.cornerRadius = 8
        connectButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        view.addSubview(connectButton)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Layout
        NSLayoutConstraint.activate([
            // Back button - top left
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            
            // IP field - top center
            ipField.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            ipField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ipField.widthAnchor.constraint(equalToConstant: 180),
            ipField.heightAnchor.constraint(equalToConstant: 36),
            
            // Connect button - top right
            connectButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            connectButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            connectButton.widthAnchor.constraint(equalToConstant: 100),
            connectButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Stream view - fills most of screen
            streamView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            streamView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            streamView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            streamView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -4),
            
            // Status label - bottom
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            statusLabel.heightAnchor.constraint(equalToConstant: 20),
        ])
        
        // Stream state callback
        streamView.onStateChanged = { [weak self] state in
            switch state {
            case .stopped:
                self?.statusLabel.text = NSLocalizedString("camera.disconnected", comment: "")
                self?.statusLabel.textColor = .lightGray
            case .loading:
                self?.statusLabel.text = NSLocalizedString("camera.connecting", comment: "")
                self?.statusLabel.textColor = .yellow
            case .playing:
                self?.statusLabel.text = NSLocalizedString("camera.streaming", comment: "")
                self?.statusLabel.textColor = .green
            case .error(let msg):
                self?.statusLabel.text = "\(NSLocalizedString("camera.error", comment: "")): \(msg)"
                self?.statusLabel.textColor = .red
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func backTapped() {
        streamView.stopStream()
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func connectTapped() {
        view.endEditing(true)
        
        let ip = ipField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "192.168.4.1"
        guard let url = URL(string: "http://\(ip):5001/video_feed") else {
            statusLabel.text = NSLocalizedString("camera.invalid_ip", comment: "")
            statusLabel.textColor = .red
            return
        }
        
        streamView.startStream(url: url)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
}
