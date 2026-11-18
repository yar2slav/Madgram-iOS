import UIKit

final class MadPatternView: UIView {
    var onFinish: (([Int]) -> Void)?
    var tint: UIColor = .white

    private var selected: [Int] = []
    private var currentPoint: CGPoint?
    private let dotRadius: CGFloat = 9.0
    private let hitRadius: CGFloat = 34.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isOpaque = false
        let pan = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        self.addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func reset() {
        self.selected = []
        self.currentPoint = nil
        self.setNeedsDisplay()
    }

    private func center(of index: Int) -> CGPoint {
        let side = min(self.bounds.width, self.bounds.height)
        let step = side / 3.0
        let originX = (self.bounds.width - side) / 2.0
        let originY = (self.bounds.height - side) / 2.0
        return CGPoint(x: originX + step * (CGFloat(index % 3) + 0.5), y: originY + step * (CGFloat(index / 3) + 0.5))
    }

    private func index(at point: CGPoint) -> Int? {
        for index in 0 ..< 9 {
            let center = self.center(of: index)
            if hypot(center.x - point.x, center.y - point.y) <= self.hitRadius {
                return index
            }
        }
        return nil
    }

    private func select(_ index: Int) {
        guard !self.selected.contains(index) else {
            return
        }
        if let last = self.selected.last {
            let lastRow = last / 3, lastColumn = last % 3
            let row = index / 3, column = index % 3
            if (lastRow + row) % 2 == 0 && (lastColumn + column) % 2 == 0 {
                let middle = ((lastRow + row) / 2) * 3 + (lastColumn + column) / 2
                if !self.selected.contains(middle) {
                    self.selected.append(middle)
                }
            }
        }
        self.selected.append(index)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            self.selected = []
            fallthrough
        case .changed:
            if let index = self.index(at: point) {
                self.select(index)
            }
            self.currentPoint = point
            self.setNeedsDisplay()
        case .ended, .cancelled, .failed:
            self.currentPoint = nil
            self.setNeedsDisplay()
            let result = self.selected
            if !result.isEmpty {
                self.onFinish?(result)
            }
        default:
            break
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        if !self.selected.isEmpty {
            context.setStrokeColor(self.tint.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(4.0)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.move(to: self.center(of: self.selected[0]))
            for index in self.selected.dropFirst() {
                context.addLine(to: self.center(of: index))
            }
            if let currentPoint = self.currentPoint {
                context.addLine(to: currentPoint)
            }
            context.strokePath()
        }
        for index in 0 ..< 9 {
            let center = self.center(of: index)
            let isSelected = self.selected.contains(index)
            let radius = isSelected ? self.dotRadius * 1.4 : self.dotRadius
            context.setFillColor(self.tint.withAlphaComponent(isSelected ? 1.0 : 0.45).cgColor)
            context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0))
        }
    }
}
