import Foundation
import UIKit
import Display
import MetalEngine
import CompanionRenderer

private final class CompanionCharacterDisplayLinkTarget: NSObject {
    weak var view: CompanionCharacterView?

    @objc func tick(_ link: CADisplayLink) {
        self.view?.tick(link)
    }
}

public final class CompanionCharacterView: UIView {
    private let character = CompanionLayer()
    private var displayLink: CADisplayLink?
    private var previousTimestamp: CFTimeInterval = 0
    private var isInWindow = false
    private var isRendererReady = false

    public var interactiveFrameChanged: ((CGRect, Bool) -> Void)?
    private var pinchStartFrame: CGRect?

    public var isEnabled: Bool = true {
        didSet {
            if self.isEnabled != oldValue {
                self.updateRunning()
            }
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.layer.addSublayer(self.character)
        self.disablesInteractiveTransitionGestureRecognizer = true

        let pan = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(self.pinchGesture(_:)))
        self.addGestureRecognizer(pinch)
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture))
        self.addGestureRecognizer(tap)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(self.doubleTapGesture))
        doubleTap.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)
        NotificationCenter.default.addObserver(self, selector: #selector(self.lookChanged), name: CompanionLookStore.didChangeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationStateChanged), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationStateChanged), name: UIApplication.didBecomeActiveNotification, object: nil)

        self.setupRenderer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func setupRenderer() {
        let bundle = Bundle(for: CompanionRenderer.self)
        guard let path = bundle.path(forResource: "CompanionResources", ofType: "bundle"), let directory = Bundle(path: path)?.resourcePath else {
            return
        }
        let renderer: CompanionRenderer
        do {
            renderer = try CompanionRenderer(device: MetalEngine.shared.device, resourceDirectory: directory)
            try renderer.loadDefault()
            CompanionLookStore.shared.apply(to: renderer)
        } catch {
            return
        }
        self.character.renderer = renderer
        self.isRendererReady = true
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let transform = self.character.transform
        self.character.transform = CATransform3DIdentity
        self.character.frame = self.bounds
        self.character.transform = transform
        if self.character.active {
            self.character.setNeedsUpdate()
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        self.isInWindow = self.window != nil
        self.updateRunning()
    }

    private func updateRunning() {
        let shouldRun = self.isInWindow && self.isEnabled && self.isRendererReady && !self.isHidden
        self.character.active = shouldRun
        if shouldRun {
            if self.displayLink == nil {
                let target = CompanionCharacterDisplayLinkTarget()
                target.view = self
                let link = CADisplayLink(target: target, selector: #selector(CompanionCharacterDisplayLinkTarget.tick(_:)))
                link.preferredFramesPerSecond = 30
                link.add(to: .main, forMode: .common)
                self.displayLink = link
            }
            self.applicationStateChanged()
            self.character.setNeedsUpdate()
        } else {
            self.displayLink?.invalidate()
            self.displayLink = nil
            self.previousTimestamp = 0
            self.character.releaseSurface()
        }
    }

    public override var isHidden: Bool {
        didSet {
            if self.isHidden != oldValue {
                self.updateRunning()
            }
        }
    }

    @objc private func applicationStateChanged() {
        self.displayLink?.isPaused = UIApplication.shared.applicationState != .active
        self.previousTimestamp = 0
    }

    fileprivate func tick(_ link: CADisplayLink) {
        self.character.deltaTime = self.previousTimestamp == 0 ? 0 : Float(min(0.1, link.timestamp - self.previousTimestamp))
        self.previousTimestamp = link.timestamp
        self.character.setNeedsUpdate()
    }

    @objc private func lookChanged() {
        guard let renderer = self.character.renderer else {
            return
        }
        do {
            try renderer.loadDefault()
        } catch {
            return
        }
        CompanionLookStore.shared.apply(to: renderer)
        self.character.setNeedsUpdate()
    }

    private func clampedFrame(_ frame: CGRect) -> CGRect {
        guard let superview = self.superview else {
            return frame
        }
        var frame = frame
        let bounds = superview.bounds
        frame.origin.x = max(bounds.minX - frame.width * 0.25, min(bounds.maxX - frame.width * 0.75, frame.origin.x))
        frame.origin.y = max(bounds.minY + 60.0, min(bounds.maxY - frame.height * 0.75, frame.origin.y))
        return frame
    }

    @objc private func panGesture(_ gesture: UIPanGestureRecognizer) {
        guard let superview = self.superview else {
            return
        }
        let offset = gesture.translation(in: superview)
        gesture.setTranslation(.zero, in: superview)
        let finished = gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed
        let frame = self.clampedFrame(self.frame.offsetBy(dx: offset.x, dy: offset.y))
        self.frame = frame
        self.interactiveFrameChanged?(frame, finished)
    }

    @objc private func pinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            self.pinchStartFrame = self.frame
        case .changed, .ended, .cancelled, .failed:
            guard let start = self.pinchStartFrame else {
                return
            }
            let side = max(CompanionChatPlacementStore.minSize, min(CompanionChatPlacementStore.maxSize, start.width * gesture.scale))
            let frame = self.clampedFrame(CGRect(x: start.midX - side * 0.5, y: start.maxY - side, width: side, height: side))
            self.frame = frame
            let finished = gesture.state != .changed
            if finished {
                self.pinchStartFrame = nil
            }
            self.interactiveFrameChanged?(frame, finished)
        default:
            break
        }
    }

    @objc private func doubleTapGesture() {
        guard let renderer = self.character.renderer else {
            return
        }
        renderer.orbitX(360.0, y: 0.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            renderer.returnToInitialOrbit()
        }
    }

    @objc private func tapGesture() {
        let currentScale = (self.character.presentation() ?? self.character).transform.m11
        self.character.removeAnimation(forKey: "transform.scale")
        self.character.transform = CATransform3DIdentity
        self.character.animateKeyframes(values: [currentScale as NSNumber, 1.18 as NSNumber, 0.94 as NSNumber, 1.0 as NSNumber], duration: 0.45, keyPath: "transform.scale")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
