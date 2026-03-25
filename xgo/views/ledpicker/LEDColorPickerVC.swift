//
//  LEDColorPickerVC.swift
//  xgo
//
//  XGO Robot LED Color Picker – controls RGB LEDs via BLE (0x69+index)
//

import UIKit

class LEDColorPickerVC: UIViewController {
    
    // MARK: - Properties
    private var currentR: CGFloat = 0
    private var currentG: CGFloat = 223/255
    private var currentB: CGFloat = 250/255
    private var selectedLedIndex: UInt8 = 0 // 0=all, 1-4=individual
    
    // MARK: - UI
    private let backButton = UIButton(type: .system)
    private let colorPreview = UIView()
    private let hexLabel = UILabel()
    
    private let rSlider = UISlider()
    private let gSlider = UISlider()
    private let bSlider = UISlider()
    private let rValueLabel = UILabel()
    private let gValueLabel = UILabel()
    private let bValueLabel = UILabel()
    
    private let brightnessSlider = UISlider()
    private let brightnessLabel = UILabel()
    
    private let ledSegment: UISegmentedControl = {
        let items = [
            NSLocalizedString("led.all", comment: "All"),
            "LED 1", "LED 2", "LED 3", "LED 4"
        ]
        let seg = UISegmentedControl(items: items)
        seg.selectedSegmentIndex = 0
        seg.selectedSegmentTintColor = UIColor(red: 0, green: 223/255, blue: 250/255, alpha: 1.0)
        let normalAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.lightGray]
        let selectedAttr: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.black]
        seg.setTitleTextAttributes(normalAttr, for: .normal)
        seg.setTitleTextAttributes(selectedAttr, for: .selected)
        return seg
    }()
    
    // Preset color buttons
    private let presetColors: [(String, UIColor)] = [
        ("led.red", UIColor.red),
        ("led.green", UIColor.green),
        ("led.blue", UIColor.blue),
        ("led.yellow", UIColor.yellow),
        ("led.cyan", UIColor.cyan),
        ("led.magenta", UIColor.magenta),
        ("led.white", UIColor.white),
        ("led.off", UIColor.black)
    ]
    
    private let presetStack = UIStackView()
    private let colorWheelView = UIView()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 23/255, green: 23/255, blue: 27/255, alpha: 1.0)
        setupUI()
        updatePreview()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("homepage.led_picker", comment: "LED Color")
        titleLabel.textColor = UIColor(red: 0, green: 223/255, blue: 250/255, alpha: 1.0)
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        backButton.setTitle(NSLocalizedString("general.back", comment: "Back"), for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(onBackTap), for: .touchUpInside)
        view.addSubview(backButton)
        
        // Color preview circle
        colorPreview.layer.cornerRadius = 40
        colorPreview.layer.borderWidth = 2
        colorPreview.layer.borderColor = UIColor.white.cgColor
        colorPreview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(colorPreview)
        
        hexLabel.text = "#00DFFA"
        hexLabel.textColor = .white
        hexLabel.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .medium)
        hexLabel.textAlignment = .center
        hexLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hexLabel)
        
        // LED segment
        ledSegment.translatesAutoresizingMaskIntoConstraints = false
        ledSegment.addTarget(self, action: #selector(onLedIndexChanged(_:)), for: .valueChanged)
        view.addSubview(ledSegment)
        
        // R/G/B sliders
        setupSlider(rSlider, color: .red, tag: 0)
        setupSlider(gSlider, color: .green, tag: 1)
        setupSlider(bSlider, color: .systemBlue, tag: 2)
        
        rValueLabel.text = "R: 0"
        gValueLabel.text = "G: 223"
        bValueLabel.text = "B: 250"
        
        let rRow = makeSliderRow(label: "R", slider: rSlider, valueLabel: rValueLabel, color: .red)
        let gRow = makeSliderRow(label: "G", slider: gSlider, valueLabel: gValueLabel, color: .green)
        let bRow = makeSliderRow(label: "B", slider: bSlider, valueLabel: bValueLabel, color: .systemBlue)
        
        rSlider.value = Float(currentR)
        gSlider.value = Float(currentG)
        bSlider.value = Float(currentB)
        
        let sliderStack = UIStackView(arrangedSubviews: [rRow, gRow, bRow])
        sliderStack.axis = .vertical
        sliderStack.spacing = 8
        sliderStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sliderStack)
        
        // Brightness
        brightnessLabel.text = NSLocalizedString("led.brightness", comment: "Brightness") + ": 100%"
        brightnessLabel.textColor = .lightGray
        brightnessLabel.font = UIFont.systemFont(ofSize: 14)
        brightnessLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(brightnessLabel)
        
        brightnessSlider.minimumValue = 0
        brightnessSlider.maximumValue = 1
        brightnessSlider.value = 1
        brightnessSlider.minimumTrackTintColor = .white
        brightnessSlider.translatesAutoresizingMaskIntoConstraints = false
        brightnessSlider.addTarget(self, action: #selector(onBrightnessChanged(_:)), for: .valueChanged)
        view.addSubview(brightnessSlider)
        
        // Preset buttons
        setupPresets()
        presetStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(presetStack)
        
        // Send button
        let sendButton = UIButton(type: .system)
        sendButton.setTitle(NSLocalizedString("led.send", comment: "Send Color"), for: .normal)
        sendButton.setTitleColor(.black, for: .normal)
        sendButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        sendButton.backgroundColor = UIColor(red: 0, green: 223/255, blue: 250/255, alpha: 1.0)
        sendButton.layer.cornerRadius = 8
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(onSendTap), for: .touchUpInside)
        view.addSubview(sendButton)
        
        // Layout
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            colorPreview.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            colorPreview.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            colorPreview.widthAnchor.constraint(equalToConstant: 80),
            colorPreview.heightAnchor.constraint(equalToConstant: 80),
            
            hexLabel.topAnchor.constraint(equalTo: colorPreview.bottomAnchor, constant: 6),
            hexLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            ledSegment.topAnchor.constraint(equalTo: hexLabel.bottomAnchor, constant: 12),
            ledSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            ledSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            sliderStack.topAnchor.constraint(equalTo: ledSegment.bottomAnchor, constant: 16),
            sliderStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sliderStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            brightnessLabel.topAnchor.constraint(equalTo: sliderStack.bottomAnchor, constant: 14),
            brightnessLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            brightnessSlider.topAnchor.constraint(equalTo: brightnessLabel.bottomAnchor, constant: 4),
            brightnessSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            brightnessSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            presetStack.topAnchor.constraint(equalTo: brightnessSlider.bottomAnchor, constant: 16),
            presetStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            presetStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            sendButton.topAnchor.constraint(equalTo: presetStack.bottomAnchor, constant: 20),
            sendButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 200),
            sendButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }
    
    private func setupSlider(_ slider: UISlider, color: UIColor, tag: Int) {
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.minimumTrackTintColor = color
        slider.tag = tag
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(onSliderChanged(_:)), for: .valueChanged)
    }
    
    private func makeSliderRow(label: String, slider: UISlider, valueLabel: UILabel, color: UIColor) -> UIStackView {
        let lbl = UILabel()
        lbl.text = label
        lbl.textColor = color
        lbl.font = UIFont.boldSystemFont(ofSize: 16)
        lbl.widthAnchor.constraint(equalToConstant: 20).isActive = true
        lbl.translatesAutoresizingMaskIntoConstraints = false
        
        valueLabel.textColor = .lightGray
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        valueLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let row = UIStackView(arrangedSubviews: [lbl, slider, valueLabel])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return row
    }
    
    private func setupPresets() {
        // Two rows of 4
        let row1 = UIStackView()
        row1.axis = .horizontal
        row1.spacing = 8
        row1.distribution = .fillEqually
        
        let row2 = UIStackView()
        row2.axis = .horizontal
        row2.spacing = 8
        row2.distribution = .fillEqually
        
        for (i, preset) in presetColors.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(NSLocalizedString(preset.0, comment: ""), for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 12)
            btn.backgroundColor = preset.1.withAlphaComponent(0.6)
            btn.layer.cornerRadius = 6
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor.gray.cgColor
            btn.tag = i
            btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
            btn.addTarget(self, action: #selector(onPresetTap(_:)), for: .touchUpInside)
            
            if i < 4 {
                row1.addArrangedSubview(btn)
            } else {
                row2.addArrangedSubview(btn)
            }
        }
        
        presetStack.axis = .vertical
        presetStack.spacing = 8
        presetStack.addArrangedSubview(row1)
        presetStack.addArrangedSubview(row2)
    }
    
    // MARK: - Actions
    @objc private func onSliderChanged(_ sender: UISlider) {
        switch sender.tag {
        case 0:
            currentR = CGFloat(sender.value)
            rValueLabel.text = "R: \(Int(currentR * 255))"
        case 1:
            currentG = CGFloat(sender.value)
            gValueLabel.text = "G: \(Int(currentG * 255))"
        case 2:
            currentB = CGFloat(sender.value)
            bValueLabel.text = "B: \(Int(currentB * 255))"
        default: break
        }
        updatePreview()
    }
    
    @objc private func onBrightnessChanged(_ sender: UISlider) {
        brightnessLabel.text = NSLocalizedString("led.brightness", comment: "Brightness") + ": \(Int(sender.value * 100))%"
        updatePreview()
    }
    
    @objc private func onLedIndexChanged(_ sender: UISegmentedControl) {
        selectedLedIndex = UInt8(sender.selectedSegmentIndex)
    }
    
    @objc private func onPresetTap(_ sender: UIButton) {
        let (_, color) = presetColors[sender.tag]
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        currentR = r
        currentG = g
        currentB = b
        rSlider.value = Float(r)
        gSlider.value = Float(g)
        bSlider.value = Float(b)
        rValueLabel.text = "R: \(Int(r * 255))"
        gValueLabel.text = "G: \(Int(g * 255))"
        bValueLabel.text = "B: \(Int(b * 255))"
        updatePreview()
        // Auto-send on preset tap
        sendColorToBLE()
    }
    
    @objc private func onSendTap() {
        sendColorToBLE()
    }
    
    @objc private func onBackTap() {
        self.navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Helpers
    private func updatePreview() {
        let brightness = CGFloat(brightnessSlider.value)
        let displayColor = UIColor(red: currentR * brightness,
                                    green: currentG * brightness,
                                    blue: currentB * brightness,
                                    alpha: 1.0)
        colorPreview.backgroundColor = displayColor
        
        let rInt = Int(currentR * brightness * 255)
        let gInt = Int(currentG * brightness * 255)
        let bInt = Int(currentB * brightness * 255)
        hexLabel.text = String(format: "#%02X%02X%02X", rInt, gInt, bInt)
    }
    
    private func sendColorToBLE() {
        let brightness = CGFloat(brightnessSlider.value)
        let r = UInt8(min(255, currentR * brightness * 255))
        let g = UInt8(min(255, currentG * brightness * 255))
        let b = UInt8(min(255, currentB * brightness * 255))
        
        if selectedLedIndex == 0 {
            // Send to all 4 LEDs
            for i: UInt8 in 0..<4 {
                FindControlUtil.setLedColor(index: i, r: r, g: g, b: b)
            }
        } else {
            FindControlUtil.setLedColor(index: selectedLedIndex - 1, r: r, g: g, b: b)
        }
        
        CBToast.showToastAction(message: NSLocalizedString("general.send_complete", comment: "") as NSString)
    }
}
