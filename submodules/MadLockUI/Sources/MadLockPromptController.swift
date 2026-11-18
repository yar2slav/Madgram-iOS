import UIKit
import LocalAuthentication
import TelegramPresentationData

final class MadLockPromptController: UIViewController, UITextFieldDelegate {
    enum Mode {
        case verify(showSkip: Bool)
        case create
    }

    private let mode: Mode
    private let strings: MadgramMoreFeatureStrings
    private let completion: (Bool, TimeInterval?) -> Void

    private var kind: MadLockKind
    private var expectedLength: Int
    private var biometricsEnabled: Bool
    private var firstEntry: String?
    private var input = ""
    private var didFinish = false

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let stack = UIStackView()
    private let titleLabel = UILabel()
    private let errorLabel = UILabel()
    private let kindControl = UISegmentedControl()
    private let dotsStack = UIStackView()
    private let padStack = UIStackView()
    private let passwordField = UITextField()
    private let patternView = MadPatternView()
    private let skipControl = UISegmentedControl()
    private let skipLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private var biometricsButton: UIButton?

    private let skipDurations: [TimeInterval?] = [nil, 15 * 60, 60 * 60, 24 * 60 * 60, -1]

    init(mode: Mode, strings: MadgramMoreFeatureStrings, completion: @escaping (Bool, TimeInterval?) -> Void) {
        self.mode = mode
        self.strings = strings
        self.completion = completion
        let stored = MadLockCredentialStore.load()
        switch mode {
        case .verify:
            self.kind = stored?.kind ?? .pin
            self.expectedLength = stored?.length ?? 4
            self.biometricsEnabled = stored?.biometrics ?? false
        case .create:
            self.kind = .pin
            self.expectedLength = 6
            self.biometricsEnabled = false
        }
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private var isCreating: Bool {
        if case .create = self.mode {
            return true
        }
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
        self.blurView.frame = self.view.bounds
        self.blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(self.blurView)

        self.stack.axis = .vertical
        self.stack.alignment = .center
        self.stack.spacing = 18.0
        self.stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.stack)
        NSLayoutConstraint.activate([
            self.stack.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            self.stack.centerYAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerYAnchor),
            self.stack.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 24.0),
            self.stack.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -24.0)
        ])

        self.titleLabel.font = .systemFont(ofSize: 20.0, weight: .semibold)
        self.titleLabel.textColor = .white
        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 0

        self.errorLabel.font = .systemFont(ofSize: 14.0)
        self.errorLabel.textColor = UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0)
        self.errorLabel.textAlignment = .center
        self.errorLabel.numberOfLines = 0
        self.errorLabel.text = " "

        if self.isCreating {
            for (index, title) in [self.strings.lockTypePin, self.strings.lockTypePassword, self.strings.lockTypePattern].enumerated() {
                self.kindControl.insertSegment(withTitle: title, at: index, animated: false)
            }
            self.kindControl.selectedSegmentIndex = 0
            self.kindControl.addTarget(self, action: #selector(self.kindChanged), for: .valueChanged)
            self.stack.addArrangedSubview(self.kindControl)
        }

        self.stack.addArrangedSubview(self.titleLabel)

        self.dotsStack.axis = .horizontal
        self.dotsStack.spacing = 16.0
        self.stack.addArrangedSubview(self.dotsStack)

        self.passwordField.isSecureTextEntry = true
        self.passwordField.textColor = .white
        self.passwordField.font = .systemFont(ofSize: 20.0)
        self.passwordField.textAlignment = .center
        self.passwordField.backgroundColor = UIColor(white: 1.0, alpha: 0.12)
        self.passwordField.layer.cornerRadius = 12.0
        self.passwordField.returnKeyType = .done
        self.passwordField.autocapitalizationType = .none
        self.passwordField.autocorrectionType = .no
        self.passwordField.delegate = self
        self.passwordField.translatesAutoresizingMaskIntoConstraints = false
        self.passwordField.widthAnchor.constraint(equalToConstant: 260.0).isActive = true
        self.passwordField.heightAnchor.constraint(equalToConstant: 48.0).isActive = true
        self.stack.addArrangedSubview(self.passwordField)

        self.patternView.translatesAutoresizingMaskIntoConstraints = false
        self.patternView.widthAnchor.constraint(equalToConstant: 260.0).isActive = true
        self.patternView.heightAnchor.constraint(equalToConstant: 260.0).isActive = true
        self.patternView.onFinish = { [weak self] indices in
            self?.submit(indices.map(String.init).joined(separator: "-"), patternCount: indices.count)
        }
        self.stack.addArrangedSubview(self.patternView)

        self.buildPad()
        self.stack.addArrangedSubview(self.padStack)
        self.stack.addArrangedSubview(self.errorLabel)

        self.doneButton.setTitle(self.strings.lockDone, for: .normal)
        self.doneButton.titleLabel?.font = .systemFont(ofSize: 17.0, weight: .semibold)
        self.doneButton.tintColor = .white
        self.doneButton.addTarget(self, action: #selector(self.donePressed), for: .touchUpInside)
        self.stack.addArrangedSubview(self.doneButton)

        if case let .verify(showSkip) = self.mode, showSkip {
            self.skipLabel.text = self.strings.skipFor
            self.skipLabel.font = .systemFont(ofSize: 13.0)
            self.skipLabel.textColor = UIColor(white: 1.0, alpha: 0.7)
            self.stack.addArrangedSubview(self.skipLabel)
            for (index, title) in [self.strings.skipNone, self.strings.skip15m, self.strings.skip1h, self.strings.skip1d, self.strings.skipUntilRestart].enumerated() {
                self.skipControl.insertSegment(withTitle: title, at: index, animated: false)
            }
            self.skipControl.selectedSegmentIndex = 0
            self.skipControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 11.0)], for: .normal)
            self.stack.addArrangedSubview(self.skipControl)
        }

        self.cancelButton.setTitle(self.strings.lockCancel, for: .normal)
        self.cancelButton.tintColor = .white
        self.cancelButton.titleLabel?.font = .systemFont(ofSize: 17.0)
        self.cancelButton.translatesAutoresizingMaskIntoConstraints = false
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), for: .touchUpInside)
        self.view.addSubview(self.cancelButton)
        NSLayoutConstraint.activate([
            self.cancelButton.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 12.0),
            self.cancelButton.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 20.0)
        ])

        self.updateKind()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if case .verify = self.mode, self.biometricsEnabled {
            self.evaluateBiometrics()
        } else if self.kind == .password {
            self.passwordField.becomeFirstResponder()
        }
    }

    private func buildPad() {
        self.padStack.axis = .vertical
        self.padStack.spacing = 14.0
        let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["bio", "0", "del"]]
        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 22.0
            for key in row {
                let button = UIButton(type: .system)
                button.translatesAutoresizingMaskIntoConstraints = false
                button.widthAnchor.constraint(equalToConstant: 74.0).isActive = true
                button.heightAnchor.constraint(equalToConstant: 74.0).isActive = true
                button.tintColor = .white
                switch key {
                case "bio":
                    if case .verify = self.mode, self.biometricsEnabled {
                        let symbol = LAContext().biometryType == .touchID ? "touchid" : "faceid"
                        button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 28.0)), for: .normal)
                        button.addTarget(self, action: #selector(self.biometricsPressed), for: .touchUpInside)
                        self.biometricsButton = button
                    } else {
                        button.isEnabled = false
                    }
                case "del":
                    button.setImage(UIImage(systemName: "delete.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24.0)), for: .normal)
                    button.addTarget(self, action: #selector(self.deletePressed), for: .touchUpInside)
                default:
                    button.setTitle(key, for: .normal)
                    button.titleLabel?.font = .systemFont(ofSize: 32.0, weight: .regular)
                    button.backgroundColor = UIColor(white: 1.0, alpha: 0.14)
                    button.layer.cornerRadius = 37.0
                    button.addTarget(self, action: #selector(self.digitPressed(_:)), for: .touchUpInside)
                }
                rowStack.addArrangedSubview(button)
            }
            self.padStack.addArrangedSubview(rowStack)
        }
    }

    private func updateKind() {
        self.input = ""
        self.passwordField.text = ""
        self.patternView.reset()
        self.dotsStack.isHidden = self.kind != .pin
        self.padStack.isHidden = self.kind != .pin
        self.passwordField.isHidden = self.kind != .password
        self.patternView.isHidden = self.kind != .pattern
        self.doneButton.isHidden = !(self.isCreating && self.kind == .pin) && self.kind != .password
        if self.kind == .password {
            self.passwordField.becomeFirstResponder()
        } else {
            self.passwordField.resignFirstResponder()
        }
        self.updateTitle()
        self.updateDots()
    }

    private func updateTitle() {
        if self.isCreating {
            if self.firstEntry == nil {
                switch self.kind {
                case .pin:
                    self.titleLabel.text = self.strings.newCode
                case .password:
                    self.titleLabel.text = self.strings.newPassword
                case .pattern:
                    self.titleLabel.text = self.strings.newPattern
                }
            } else {
                self.titleLabel.text = self.kind == .pattern ? self.strings.repeatPattern : self.strings.repeatCode
            }
            self.kindControl.isEnabled = self.firstEntry == nil
        } else {
            switch self.kind {
            case .pin:
                self.titleLabel.text = self.strings.enterCode
            case .password:
                self.titleLabel.text = self.strings.enterPassword
            case .pattern:
                self.titleLabel.text = self.strings.drawPattern
            }
        }
    }

    private func updateDots() {
        self.dotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let count = self.isCreating ? max(4, min(6, self.input.count + (self.input.count < 6 ? 1 : 0))) : self.expectedLength
        for index in 0 ..< count {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 14.0).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 14.0).isActive = true
            dot.layer.cornerRadius = 7.0
            dot.layer.borderWidth = 1.5
            dot.layer.borderColor = UIColor.white.cgColor
            dot.backgroundColor = index < self.input.count ? .white : .clear
            self.dotsStack.addArrangedSubview(dot)
        }
    }

    @objc private func kindChanged() {
        self.kind = MadLockKind.allCases[max(0, self.kindControl.selectedSegmentIndex)]
        self.errorLabel.text = " "
        self.updateKind()
    }

    @objc private func digitPressed(_ sender: UIButton) {
        guard let digit = sender.title(for: .normal) else {
            return
        }
        let limit = self.isCreating ? 6 : self.expectedLength
        guard self.input.count < limit else {
            return
        }
        self.input.append(digit)
        self.updateDots()
        if self.input.count == limit {
            let value = self.input
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.submit(value, patternCount: 0)
            }
        }
    }

    @objc private func deletePressed() {
        if !self.input.isEmpty {
            self.input.removeLast()
            self.updateDots()
        }
    }

    @objc private func donePressed() {
        switch self.kind {
        case .pin:
            if self.input.count >= 4 {
                self.submit(self.input, patternCount: 0)
            }
        case .password:
            self.submit(self.passwordField.text ?? "", patternCount: 0)
        case .pattern:
            break
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.donePressed()
        return false
    }

    @objc private func cancelPressed() {
        self.finish(false)
    }

    @objc private func biometricsPressed() {
        self.evaluateBiometrics()
    }

    private func evaluateBiometrics() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: self.strings.lockUnlockReason) { [weak self] success, _ in
            DispatchQueue.main.async {
                if success {
                    MadLockCredentialStore.resetFailures()
                    self?.finish(true)
                }
            }
        }
    }

    private func showError(_ text: String) {
        self.errorLabel.text = text
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, -12, 12, -8, 8, -4, 4, 0]
        animation.duration = 0.4
        self.stack.layer.add(animation, forKey: "shake")
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        self.input = ""
        self.passwordField.text = ""
        self.patternView.reset()
        self.updateDots()
    }

    private func submit(_ secret: String, patternCount: Int) {
        if secret.isEmpty {
            return
        }
        if self.isCreating {
            if self.kind == .pattern && patternCount < 4 {
                self.showError(self.strings.lockPatternTooShort)
                return
            }
            if let firstEntry = self.firstEntry {
                if firstEntry == secret {
                    let canUseBiometrics = LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
                    MadLockCredentialStore.store(MadLockCredentialStore.makeCredential(kind: self.kind, secret: secret, biometrics: canUseBiometrics))
                    self.finish(true)
                } else {
                    self.firstEntry = nil
                    self.updateTitle()
                    self.showError(self.strings.lockMismatch)
                }
            } else {
                self.firstEntry = secret
                self.errorLabel.text = " "
                self.input = ""
                self.passwordField.text = ""
                self.patternView.reset()
                self.updateTitle()
                self.updateDots()
            }
        } else {
            let blocked = MadLockCredentialStore.blockedFor
            if blocked > 0 {
                self.showError("\(self.strings.lockWrong) · \(Int(ceil(blocked)))s")
                return
            }
            if MadLockCredentialStore.verify(secret) {
                MadLockCredentialStore.resetFailures()
                self.finish(true)
            } else {
                MadLockCredentialStore.registerFailure()
                let delay = MadLockCredentialStore.blockedFor
                self.showError(delay > 0 ? "\(self.strings.lockWrong) · \(Int(ceil(delay)))s" : self.strings.lockWrong)
            }
        }
    }

    private func finish(_ success: Bool) {
        guard !self.didFinish else {
            return
        }
        self.didFinish = true
        var skip: TimeInterval?
        if success, case let .verify(showSkip) = self.mode, showSkip {
            let index = self.skipControl.selectedSegmentIndex
            if index >= 0 && index < self.skipDurations.count {
                skip = self.skipDurations[index]
            }
        }
        self.passwordField.resignFirstResponder()
        let completion = self.completion
        self.dismiss(animated: true, completion: {
            completion(success, skip)
        })
    }
}
