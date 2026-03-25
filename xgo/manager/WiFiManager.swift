//
//  WiFiManager.swift
//  xgo
//
//  WiFi connection manager for XGO Rider CM4
//  Communicates with Flask/SocketIO server on CM4
//

import Foundation
import SocketIO

/// Manages WiFi connection to XGO Rider CM4 via SocketIO
final class WiFiManager {
    
    static let shared = WiFiManager()
    
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    
    /// Connection state
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    private(set) var state: ConnectionState = .disconnected
    
    /// Callbacks
    var onStateChanged: ((ConnectionState) -> Void)?
    
    /// Default CM4 IP and port
    private(set) var host: String = "192.168.4.1"
    private(set) var port: Int = 80
    
    /// Video stream URL (MJPEG on port 5001)
    var videoStreamURL: URL? {
        return URL(string: "http://\(host):5001/video_feed")
    }
    
    private init() {}
    
    // MARK: - Connection
    
    func connect(host: String, port: Int = 80) {
        disconnect()
        
        self.host = host
        self.port = port
        
        let urlString = "http://\(host):\(port)"
        guard let url = URL(string: urlString) else { return }
        
        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .reconnects(true),
            .reconnectWait(2),
            .reconnectAttempts(5)
        ])
        
        socket = manager?.defaultSocket
        
        setupSocketEvents()
        
        state = .connecting
        onStateChanged?(.connecting)
        socket?.connect()
    }
    
    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager?.disconnect()
        manager = nil
        state = .disconnected
        onStateChanged?(.disconnected)
    }
    
    private func setupSocketEvents() {
        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            self?.state = .connected
            self?.onStateChanged?(.connected)
            print("[WiFi] Connected to CM4")
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            self?.state = .disconnected
            self?.onStateChanged?(.disconnected)
            print("[WiFi] Disconnected from CM4")
        }
        
        socket?.on(clientEvent: .error) { _, data in
            print("[WiFi] Error: \(data)")
        }
        
        socket?.on(clientEvent: .reconnect) { [weak self] _, _ in
            self?.state = .connecting
            self?.onStateChanged?(.connecting)
            print("[WiFi] Reconnecting...")
        }
    }
    
    // MARK: - Movement Commands
    
    /// Move forward/backward (speed: 0-255, 128=stop)
    func moveForward(speed: Int) {
        socket?.emit("up", speed)
    }
    
    func moveBackward(speed: Int) {
        socket?.emit("down", speed)
    }
    
    /// Turn left/right (speed: 0-255, 128=stop)
    func turnLeft(speed: Int) {
        socket?.emit("left", speed)
    }
    
    func turnRight(speed: Int) {
        socket?.emit("right", speed)
    }
    
    /// Stop all movement
    func stopMovement() {
        socket?.emit("up", 128)
        socket?.emit("left", 128)
    }
    
    // MARK: - Action Commands
    
    /// Perform action by number (matches ShowMode actions)
    func performAction(number: Int) {
        socket?.emit("action", number)
    }
    
    /// Reset robot to default stance
    func reset() {
        socket?.emit("reset", 0)
    }
    
    /// Set height (0-100, maps to servo angle on CM4 side)
    func setHeight(value: Int) {
        socket?.emit("height", value)
    }
    
    /// IMU self-balance ON/OFF
    func setBalance(enabled: Bool) {
        socket?.emit("balance", enabled ? 1 : 0)
    }
    
    // MARK: - Gesture Commands (from CM4 web interface)
    
    func leftRight(value: Int) {
        socket?.emit("LeftRight", value)
    }
    
    func upDown(value: Int) {
        socket?.emit("UpDown", value)
    }
    
    func goBack(value: Int) {
        socket?.emit("GoBack", value)
    }
    
    func square(value: Int) {
        socket?.emit("Square", value)
    }
    
    func liftRotate(value: Int) {
        socket?.emit("LiftRotate", value)
    }
    
    func swaying(value: Int) {
        socket?.emit("Swaying", value)
    }
}
