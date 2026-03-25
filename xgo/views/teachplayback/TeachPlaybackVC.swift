//
//  TeachPlaybackVC.swift
//  xgo
//
//  XGO Robot Teach & Playback – record movement sequences and replay
//  Records timestamped BLE commands (moveX/Y, turn, height, actions)
//  and replays them with original timing.
//

import UIKit

// MARK: - Recording Data Model

struct RecordedCommand: Codable {
    let timestamp: TimeInterval  // seconds since recording start
    let type: CommandType
    let value: UInt8
    
    enum CommandType: String, Codable {
        case moveX      // 0x30
        case moveY      // 0x31
        case turn       // 0x32
        case height     // 0x35
        case rollAngle  // 0x36
        case pitchAngle // 0x37
        case yawAngle   // 0x38
        case action     // 0x3E
    }
}

struct RecordedSequence: Codable {
    var name: String
    var commands: [RecordedCommand]
    var duration: TimeInterval
    let createdAt: Date
}

// MARK: - TeachPlaybackVC

class TeachPlaybackVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - State
    private enum Mode {
        case idle
        case recording
        case playing
    }
    
    private var mode: Mode = .idle
    private var recordingStartTime: Date?
    private var currentCommands: [RecordedCommand] = []
    private var savedSequences: [RecordedSequence] = []
    private var playbackTimer: Timer?
    private var playbackIndex: Int = 0
    private var playbackStartTime: Date?
    
    // Recording timers for continuous input
    private var moveTimer: Timer?
    
    // Live joystick state
    private var liveX: UInt8 = 0x80
    private var liveY: UInt8 = 0x80
    private var liveTurn: UInt8 = 0x80
    
    // MARK: - UI
    private let backButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let timerLabel = UILabel()
    private let recordButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    
    // Recording controls — joystick area
    private let joystickArea = UIView()
    private let joystickKnob = UIView()
    private var joystickCenter = CGPoint.zero
    
    // Height slider during recording
    private let heightSlider = UISlider()
    private let heightLabel = UILabel()
    
    // Action quick buttons during recording
    private let actionStack = UIStackView()
    
    // Saved sequences table
    private let tableView = UITableView()
    
    private var displayTimer: Timer?
    private var recordingSeconds: Int = 0
    
    private static let storageKey = "xgo_recorded_sequences"
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 23/255, green: 23/255, blue: 27/255, alpha: 1.0)
        loadSequences()
        setupUI()
        updateUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRecording()
        stopPlayback()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("homepage.teach_playback", comment: "Teach & Playback")
        titleLabel.textColor = UIColor(red: 0, green: 223/255, blue: 250/255, alpha: 1.0)
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        backButton.setTitle(NSLocalizedString("general.back", comment: ""), for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(onBackTap), for: .touchUpInside)
        view.addSubview(backButton)
        
        // Status
        statusLabel.text = NSLocalizedString("teach.ready", comment: "Ready")
        statusLabel.textColor = .lightGray
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        timerLabel.text = "00:00"
        timerLabel.textColor = .white
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        timerLabel.textAlignment = .center
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timerLabel)
        
        // Control buttons
        setupButton(recordButton, title: "\u{23FA} " + NSLocalizedString("teach.record", comment: "Record"),
                    bg: UIColor.systemRed)
        recordButton.addTarget(self, action: #selector(onRecordTap), for: .touchUpInside)
        
        setupButton(stopButton, title: "\u{23F9} " + NSLocalizedString("teach.stop", comment: "Stop"),
                    bg: UIColor.systemGray)
        stopButton.addTarget(self, action: #selector(onStopTap), for: .touchUpInside)
        
        setupButton(playButton, title: "\u{25B6} " + NSLocalizedString("teach.play", comment: "Play"),
                    bg: UIColor(red: 0, green: 223/255, blue: 250/255, alpha: 1.0))
        playButton.addTarget(self, action: #selector(onPlayTap), for: .touchUpInside)
        
        let buttonStack = UIStackView(arrangedSubviews: [recordButton, stopButton, playButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)
        
        // Joystick area (for recording)
        joystickArea.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        joystickArea.layer.cornerRadius = 60
        joystickArea.layer.borderWidth = 2
        joystickArea.layer.borderColor = UIColor.darkGray.cgColor
        joystickArea.translatesAutoresizingMaskIntoConstraints = false
        joystickArea.isHidden = true
        view.addSubview(joystickArea)
        
        joystickKnob.backgroundColor = UIColor(red: 0, green: 223/255, blue: 250/255, alpha: 0.8)
        joystickKnob.layer.cornerRadius = 20
        joystickKnob.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        joystickArea.addSubview(joystickKnob)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(onJoystickPan(_:)))
        joystickArea.addGestureRecognizer(panGesture)
        
        // Height slider (for recording)
        heightLabel.text = NSLocalizedString("general.height", comment: "Height") + ": 50%"
        heightLabel.textColor = .lightGray
        heightLabel.font = UIFont.systemFont(ofSize: 14)
        heightLabel.translatesAutoresizingMaskIntoConstraints = false
        heightLabel.isHidden = true
        view.addSubview(heightLabel)
        
        heightSlider.minimumValue = 0
        heightSlider.maximumValue = 255
        heightSlider.value = 128
        heightSlider.minimumTrackTintColor = UIColor(red: 0, green: 223/255, blue: 250/255, alpha: 1.0)
        heightSlider.translatesAutoresizingMaskIntoConstraints = false
        heightSlider.isHidden = true
        heightSlider.addTarget(self, action: #selector(onHeightChanged(_:)), for: .valueChanged)
        view.addSubview(heightSlider)
        
        // Action buttons during recording
        let actions: [(String, UInt8)] = [
            (NSLocalizedString("action.spin", comment: "Spin"), 4),
            (NSLocalizedString("action.wave_hand", comment: "Wave"), 13),
            (NSLocalizedString("action.dance1", comment: "Dance1"), 21),
            (NSLocalizedString("action.balance_demo", comment: "Balance"), 23)
        ]
        
        actionStack.axis = .horizontal
        actionStack.spacing = 8
        actionStack.distribution = .fillEqually
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.isHidden = true
        
        for (title, actionId) in actions {
            let btn = UIButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 12)
            btn.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
            btn.layer.cornerRadius = 6
            btn.tag = Int(actionId)
            btn.heightAnchor.constraint(equalToConstant: 34).isActive = true
            btn.addTarget(self, action: #selector(onActionTap(_:)), for: .touchUpInside)
            actionStack.addArrangedSubview(btn)
        }
        view.addSubview(actionStack)
        
        // Table view for saved sequences
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SeqCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorColor = UIColor.darkGray
        view.addSubview(tableView)
        
        let listTitle = UILabel()
        listTitle.text = NSLocalizedString("teach.saved_sequences", comment: "Saved Sequences")
        listTitle.textColor = .lightGray
        listTitle.font = UIFont.systemFont(ofSize: 14)
        listTitle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(listTitle)
        
        // Layout
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            timerLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            buttonStack.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 44),
            
            joystickArea.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 16),
            joystickArea.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -80),
            joystickArea.widthAnchor.constraint(equalToConstant: 120),
            joystickArea.heightAnchor.constraint(equalToConstant: 120),
            
            heightLabel.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 16),
            heightLabel.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10),
            
            heightSlider.topAnchor.constraint(equalTo: heightLabel.bottomAnchor, constant: 4),
            heightSlider.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10),
            heightSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            actionStack.topAnchor.constraint(equalTo: joystickArea.bottomAnchor, constant: 12),
            actionStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actionStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            listTitle.topAnchor.constraint(equalTo: actionStack.bottomAnchor, constant: 16),
            listTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            tableView.topAnchor.constraint(equalTo: listTitle.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
    }
    
    private func setupButton(_ btn: UIButton, title: String, bg: UIColor) {
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        btn.backgroundColor = bg
        btn.layer.cornerRadius = 8
        btn.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func updateUI() {
        let isIdle = mode == .idle
        let isRecording = mode == .recording
        let isPlaying = mode == .playing
        
        recordButton.isEnabled = isIdle
        recordButton.alpha = isIdle ? 1 : 0.4
        stopButton.isEnabled = !isIdle
        stopButton.alpha = !isIdle ? 1 : 0.4
        playButton.isEnabled = isIdle && !savedSequences.isEmpty
        playButton.alpha = (isIdle && !savedSequences.isEmpty) ? 1 : 0.4
        
        // Show/hide recording controls
        joystickArea.isHidden = !isRecording
        heightLabel.isHidden = !isRecording
        heightSlider.isHidden = !isRecording
        actionStack.isHidden = !isRecording
        tableView.isHidden = isRecording
        
        switch mode {
        case .idle:
            statusLabel.text = NSLocalizedString("teach.ready", comment: "Ready")
            statusLabel.textColor = .lightGray
        case .recording:
            statusLabel.text = "\u{1F534} " + NSLocalizedString("teach.recording", comment: "Recording...")
            statusLabel.textColor = .systemRed
        case .playing:
            statusLabel.text = "\u{25B6} " + NSLocalizedString("teach.playing", comment: "Playing...")
            statusLabel.textColor = UIColor(red: 0, green: 223/255, blue: 250/255, alpha: 1.0)
        }
    }
    
    // MARK: - Recording
    @objc private func onRecordTap() {
        startRecording()
    }
    
    @objc private func onStopTap() {
        if mode == .recording {
            stopRecording()
        } else if mode == .playing {
            stopPlayback()
        }
    }
    
    @objc private func onPlayTap() {
        guard let selected = tableView.indexPathForSelectedRow else {
            // Play last saved
            if let last = savedSequences.last {
                startPlayback(last)
            }
            return
        }
        startPlayback(savedSequences[selected.row])
    }
    
    private func startRecording() {
        mode = .recording
        currentCommands = []
        recordingStartTime = Date()
        recordingSeconds = 0
        timerLabel.text = "00:00"
        
        // Start display timer
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingSeconds += 1
            let mins = self.recordingSeconds / 60
            let secs = self.recordingSeconds % 60
            self.timerLabel.text = String(format: "%02d:%02d", mins, secs)
        }
        
        // Start move command timer (send live joystick state at 10Hz)
        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.liveX != 0x80 || self.liveY != 0x80 {
                self.recordCommand(type: .moveX, value: self.liveX)
                self.recordCommand(type: .moveY, value: self.liveY)
                FindControlUtil.moveX(speed: self.liveX)
                FindControlUtil.moveY(speed: self.liveY)
            }
        }
        
        // Reset joystick knob position
        liveX = 0x80
        liveY = 0x80
        liveTurn = 0x80
        
        updateUI()
    }
    
    private func stopRecording() {
        guard mode == .recording else { return }
        mode = .idle
        displayTimer?.invalidate()
        displayTimer = nil
        moveTimer?.invalidate()
        moveTimer = nil
        
        // Stop robot
        FindControlUtil.moveX(speed: 0x80)
        FindControlUtil.moveY(speed: 0x80)
        FindControlUtil.turnClockwise(speed: 0x80)
        
        guard !currentCommands.isEmpty else {
            updateUI()
            return
        }
        
        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())
        
        // Prompt for name
        let alert = UIAlertController(
            title: NSLocalizedString("teach.save_title", comment: "Save Recording"),
            message: NSLocalizedString("teach.save_message", comment: "Name this sequence:"),
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss"
            tf.text = "Seq \(df.string(from: Date()))"
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("ble.ok", comment: "OK"), style: .default) { [weak self] _ in
            guard let self = self else { return }
            let name = alert.textFields?.first?.text ?? "Sequence"
            let seq = RecordedSequence(name: name, commands: self.currentCommands, duration: duration, createdAt: Date())
            self.savedSequences.append(seq)
            self.saveSequences()
            self.tableView.reloadData()
            self.updateUI()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("teach.discard", comment: "Discard"), style: .destructive) { [weak self] _ in
            self?.updateUI()
        })
        present(alert, animated: true)
    }
    
    private func recordCommand(type: RecordedCommand.CommandType, value: UInt8) {
        guard let start = recordingStartTime else { return }
        let ts = Date().timeIntervalSince(start)
        let cmd = RecordedCommand(timestamp: ts, type: type, value: value)
        currentCommands.append(cmd)
    }
    
    // MARK: - Playback
    private func startPlayback(_ sequence: RecordedSequence) {
        guard !sequence.commands.isEmpty else { return }
        mode = .playing
        playbackIndex = 0
        playbackStartTime = Date()
        recordingSeconds = 0
        timerLabel.text = "00:00"
        updateUI()
        
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingSeconds += 1
            let mins = self.recordingSeconds / 60
            let secs = self.recordingSeconds % 60
            self.timerLabel.text = String(format: "%02d:%02d", mins, secs)
        }
        
        let commands = sequence.commands
        
        // Use repeating timer at 50ms resolution
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self, let start = self.playbackStartTime else {
                timer.invalidate()
                return
            }
            
            let elapsed = Date().timeIntervalSince(start)
            
            // Execute all commands up to current time
            while self.playbackIndex < commands.count && commands[self.playbackIndex].timestamp <= elapsed {
                let cmd = commands[self.playbackIndex]
                self.executeCommand(cmd)
                self.playbackIndex += 1
            }
            
            // Check if done
            if self.playbackIndex >= commands.count {
                self.stopPlayback()
            }
        }
    }
    
    private func stopPlayback() {
        guard mode == .playing else { return }
        mode = .idle
        playbackTimer?.invalidate()
        playbackTimer = nil
        displayTimer?.invalidate()
        displayTimer = nil
        
        // Stop robot
        FindControlUtil.moveX(speed: 0x80)
        FindControlUtil.moveY(speed: 0x80)
        FindControlUtil.turnClockwise(speed: 0x80)
        
        updateUI()
        CBToast.showToastAction(message: NSLocalizedString("teach.playback_done", comment: "Playback complete") as NSString)
    }
    
    private func executeCommand(_ cmd: RecordedCommand) {
        switch cmd.type {
        case .moveX:
            FindControlUtil.moveX(speed: cmd.value)
        case .moveY:
            FindControlUtil.moveY(speed: cmd.value)
        case .turn:
            FindControlUtil.turnClockwise(speed: cmd.value)
        case .height:
            FindControlUtil.heightSet(height: cmd.value)
        case .rollAngle:
            FindControlUtil.trunByX(angle: cmd.value)
        case .pitchAngle:
            FindControlUtil.trunByY(angle: cmd.value)
        case .yawAngle:
            FindControlUtil.trunByZ(angle: cmd.value)
        case .action:
            FindControlUtil.actionType(type: cmd.value)
        }
    }
    
    // MARK: - Joystick
    @objc private func onJoystickPan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: joystickArea)
        let center = CGPoint(x: joystickArea.bounds.midX, y: joystickArea.bounds.midY)
        let maxRadius: CGFloat = 40
        
        switch gesture.state {
        case .changed:
            var dx = location.x - center.x
            var dy = location.y - center.y
            let dist = sqrt(dx*dx + dy*dy)
            if dist > maxRadius {
                dx = dx / dist * maxRadius
                dy = dy / dist * maxRadius
            }
            
            joystickKnob.center = CGPoint(x: center.x + dx, y: center.y + dy)
            
            // Map to 0x00-0xFF (center=0x80)
            liveX = UInt8(clamping: Int(128 - dy / maxRadius * 127))  // forward = low Y = high value
            liveY = UInt8(clamping: Int(128 + dx / maxRadius * 127))  // right = high X
            
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.2) {
                self.joystickKnob.center = center
            }
            liveX = 0x80
            liveY = 0x80
            // Record stop commands
            recordCommand(type: .moveX, value: 0x80)
            recordCommand(type: .moveY, value: 0x80)
            FindControlUtil.moveX(speed: 0x80)
            FindControlUtil.moveY(speed: 0x80)
            
        default: break
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let center = CGPoint(x: joystickArea.bounds.midX, y: joystickArea.bounds.midY)
        if joystickKnob.center == .zero || mode != .recording {
            joystickKnob.center = center
        }
    }
    
    // MARK: - Height & Actions
    @objc private func onHeightChanged(_ sender: UISlider) {
        let val = UInt8(sender.value)
        heightLabel.text = NSLocalizedString("general.height", comment: "Height") + ": \(Int(sender.value / 255 * 100))%"
        recordCommand(type: .height, value: val)
        FindControlUtil.heightSet(height: val)
    }
    
    @objc private func onActionTap(_ sender: UIButton) {
        let actionId = UInt8(sender.tag)
        recordCommand(type: .action, value: actionId)
        FindControlUtil.actionType(type: actionId)
    }
    
    // MARK: - Persistence (UserDefaults)
    private func saveSequences() {
        if let data = try? JSONEncoder().encode(savedSequences) {
            UserDefaults.standard.set(data, forKey: TeachPlaybackVC.storageKey)
        }
    }
    
    private func loadSequences() {
        if let data = UserDefaults.standard.data(forKey: TeachPlaybackVC.storageKey),
           let seqs = try? JSONDecoder().decode([RecordedSequence].self, from: data) {
            savedSequences = seqs
        }
    }
    
    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return savedSequences.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SeqCell", for: indexPath)
        let seq = savedSequences[indexPath.row]
        let durStr = String(format: "%.1fs", seq.duration)
        let cmds = seq.commands.count
        cell.textLabel?.text = "\(seq.name)  (\(durStr), \(cmds) cmds)"
        cell.textLabel?.textColor = .white
        cell.backgroundColor = .clear
        cell.selectionStyle = .gray
        let bg = UIView()
        bg.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        cell.selectedBackgroundView = bg
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Selection is used for Play button
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            savedSequences.remove(at: indexPath.row)
            saveSequences()
            tableView.deleteRows(at: [indexPath], with: .fade)
            updateUI()
        }
    }
    
    // MARK: - Navigation
    @objc private func onBackTap() {
        self.navigationController?.popViewController(animated: true)
    }
}
