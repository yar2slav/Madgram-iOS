import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import GlassBackgroundComponent

public protocol HeaderPanelContainerChildView: UIView {
    func setOverlayContainerView(overlayContainerView: UIView)
}

public final class HeaderPanelContainerComponent: Component {
    public final class Panel: Equatable {
        public let key: AnyHashable
        public let orderIndex: Int
        public let component: AnyComponent<Empty>
        
        public init(key: AnyHashable, orderIndex: Int, component: AnyComponent<Empty>) {
            self.key = key
            self.orderIndex = orderIndex
            self.component = component
        }
        
        public static func ==(lhs: Panel, rhs: Panel) -> Bool {
            if lhs.key != rhs.key {
                return false
            }
            if lhs.orderIndex != rhs.orderIndex {
                return false
            }
            if lhs.component != rhs.component {
                return false
            }
            return true
        }
    }
    
    public let theme: PresentationTheme
    public let preferClearGlass: Bool
    public let tabs: AnyComponent<Empty>?
    public let panels: [Panel]
    /// A stack shown above the input panel (the chat's bottom topics panel) rather than under the navigation bar.
    /// Classic design flattens only the header stack: a footer keeps its floating platter.
    public let isFooter: Bool
    
    public init(
        theme: PresentationTheme,
        preferClearGlass: Bool = false,
        tabs: AnyComponent<Empty>?,
        panels: [Panel],
        isFooter: Bool = false
    ) {
        self.theme = theme
        self.preferClearGlass = preferClearGlass
        self.tabs = tabs
        self.panels = panels
        self.isFooter = isFooter
    }
    
    public static func ==(lhs: HeaderPanelContainerComponent, rhs: HeaderPanelContainerComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.preferClearGlass != rhs.preferClearGlass {
            return false
        }
        if lhs.tabs != rhs.tabs {
            return false
        }
        if lhs.panels != rhs.panels {
            return false
        }
        if lhs.isFooter != rhs.isFooter {
            return false
        }
        return true
    }
    
    private final class PanelItemView: UIView {
        let view = ComponentView<Empty>()
        let separator = SimpleLayer()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    public final class View: UIView {
        private let backgroundContainer: GlassBackgroundContainerView
        private let backgroundView: GlassBackgroundView
        private let contentContainer: UIView
        
        private var tabsView: ComponentView<Empty>?
        private var panelViews: [AnyHashable: PanelItemView] = [:]
        
        /// Classic (12.0): a stack without tabs (the chat's title accessory panels) is a full-width flat strip in the
        /// navigation bar's colours, with a hairline under it, instead of a floating glass platter.
        private var classicBackgroundNode: NavigationBackgroundNode?
        private var classicSeparatorLayer: SimpleLayer?
        
        private var component: HeaderPanelContainerComponent?
        private weak var state: EmptyComponentState?
        
        public var tabs: UIView? {
            return self.tabsView?.view
        }
        
        public func panel(forKey key: AnyHashable) -> UIView? {
            return self.panelViews[key]?.view.view
        }
        
        override init(frame: CGRect) {
            self.backgroundContainer = GlassBackgroundContainerView()
            self.backgroundView = GlassBackgroundView()
            self.contentContainer = UIView()
            self.contentContainer.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.backgroundContainer.contentView.addSubview(self.backgroundView)
            self.addSubview(self.backgroundContainer)
            
            self.backgroundView.contentView.addSubview(self.contentContainer)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: HeaderPanelContainerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            var isAnimatingReplacement = false
            if let previousComponent = self.component {
                isAnimatingReplacement = !component.panels.contains(where: { panel in previousComponent.panels.contains(where: { $0.key == panel.key }) })
            }
            
            self.component = component
            self.state = state
            
            let isClassicFlat = ClassicDesign.isEnabled && component.tabs == nil && !component.isFooter
            // Classic (12.0) with tabs (the chat list's folder tabs): no platter or background of its own, full width.
            // `ChatListNavigationBar` draws the flat bar and its hairline behind it, and `HorizontalTabsComponent` its own
            // selection underline.
            let isClassicBare = ClassicDesign.isEnabled && component.tabs != nil && !component.isFooter
            let sideInset: CGFloat = (isClassicFlat || isClassicBare) ? 0.0 : 16.0
            
            var size = CGSize(width: availableSize.width, height: 0.0)
            
            var isFirstPanel = true
            
            if let tabs = component.tabs {
                let tabsView: ComponentView<Empty>
                var tabsTransition = transition
                if let current = self.tabsView {
                    tabsView = current
                } else {
                    tabsTransition = tabsTransition.withAnimation(.none)
                    tabsView = ComponentView()
                    self.tabsView = tabsView
                }
                let tabsSize = tabsView.update(
                    transition: tabsTransition,
                    component: tabs,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 40.0)
                )
                let tabsFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height), size: tabsSize)
                if let tabsComponentView = tabsView.view {
                    if tabsComponentView.superview == nil {
                        self.contentContainer.addSubview(tabsComponentView)
                        if let tabsComponentView = tabsComponentView as? HeaderPanelContainerChildView {
                            tabsComponentView.setOverlayContainerView(overlayContainerView: self.backgroundContainer.contentView)
                        }
                        transition.animateAlpha(view: tabsComponentView, from: 0.0, to: 1.0)
                    }
                    tabsTransition.setFrame(view: tabsComponentView, frame: tabsFrame)
                }
                size.height += tabsSize.height
                isFirstPanel = false
            } else if let tabsView = self.tabsView {
                self.tabsView = nil
                if let tabsComponentView = tabsView.view {
                    transition.setAlpha(view: tabsComponentView, alpha: 0.0, completion: { [weak tabsComponentView] _ in
                        tabsComponentView?.removeFromSuperview()
                    })
                }
            }
            
            var validPanelKeys: [AnyHashable] = []
            for panel in component.panels {
                validPanelKeys.append(panel.key)
                
                var panelTransition = transition
                let panelView: PanelItemView
                if let current = self.panelViews[panel.key] {
                    panelView = current
                } else {
                    panelTransition = panelTransition.withAnimation(.none)
                    panelView = PanelItemView()
                    self.panelViews[panel.key] = panelView
                    self.contentContainer.layer.insertSublayer(panelView.separator, at: 0)
                    self.contentContainer.addSubview(panelView)
                }
                
                let panelSize = panelView.view.update(
                    transition: panelTransition,
                    component: panel.component,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height), size: panelSize)
                if let panelComponentView = panelView.view.view {
                    if panelComponentView.superview == nil {
                        panelView.addSubview(panelComponentView)
                        transition.animateAlpha(view: panelView, from: 0.0, to: 1.0)
                        panelView.separator.opacity = 0.0
                        panelView.clipsToBounds = true
                        if isAnimatingReplacement {
                            panelView.frame = panelFrame
                        } else {
                            panelView.frame = CGRect(origin: panelFrame.origin, size: CGSize(width: panelFrame.width, height: 0.0))
                        }
                    }
                    
                    panelView.separator.backgroundColor = ((isClassicFlat || isClassicBare) ? component.theme.rootController.navigationBar.separatorColor : component.theme.list.itemPlainSeparatorColor).cgColor
                    
                    let isFrameUpdated = panelComponentView.frame != panelFrame
                    transition.setFrame(view: panelView, frame: panelFrame, completion: { [weak panelView] completed in
                        if let panelView, completed, isFrameUpdated {
                            panelView.clipsToBounds = false
                        }
                    })
                    panelTransition.setFrame(view: panelComponentView, frame: CGRect(origin: CGPoint(), size: panelFrame.size))
                    panelTransition.setFrame(layer: panelView.separator, frame: CGRect(origin: panelFrame.origin, size: CGSize(width: panelFrame.width, height: UIScreenPixel)))
                    
                    transition.setAlpha(layer: panelView.separator, alpha: isFirstPanel ? 0.0 : 1.0)
                }
                size.height += panelSize.height
                isFirstPanel = false
            }
            
            var removedPanelKeys: [AnyHashable] = []
            for (key, panelView) in self.panelViews {
                if !validPanelKeys.contains(key) {
                    removedPanelKeys.append(key)
                    transition.setAlpha(view: panelView, alpha: 0.0, completion: { [weak panelView] _ in
                        panelView?.removeFromSuperview()
                    })
                    let separator = panelView.separator
                    transition.setAlpha(layer: separator, alpha: 0.0, completion: { [weak separator] _ in
                        separator?.removeFromSuperlayer()
                    })
                    if !isAnimatingReplacement {
                        panelView.clipsToBounds = true
                        transition.setFrame(view: panelView, frame: CGRect(origin: panelView.frame.origin, size: CGSize(width: panelView.bounds.width, height: 0.0)))
                    }
                }
            }
            for key in removedPanelKeys {
                self.panelViews.removeValue(forKey: key)
            }
            
            if isClassicFlat {
                self.updateClassicBackground(component: component, size: size, transition: transition)
                return size
            } else if isClassicBare {
                self.updateClassicBare(size: size, transition: transition)
                return size
            } else if self.classicBackgroundNode != nil || self.contentContainer.superview !== self.backgroundView.contentView {
                self.removeClassicBackground()
            }
            
            let backgroundSize = CGSize(width: size.width, height: max(40.0, size.height))
            
            transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: backgroundSize).insetBy(dx: -32.0, dy: -32.0))
            self.backgroundContainer.update(size: CGSize(width: backgroundSize.width + 32.0 * 2.0, height: backgroundSize.height + 32.0 * 2.0), isDark: component.theme.overallDarkAppearance, transition: transition)
            
            let backgroundFrame = CGRect(origin: CGPoint(x: 32.0 + sideInset, y: 32.0), size: CGSize(width: size.width - sideInset * 2.0, height: backgroundSize.height))
            
            var panelCount = 0
            if component.tabs != nil {
                panelCount += 1
            }
            panelCount += component.panels.count
            var cornerRadius: CGFloat = 0.0
            if panelCount == 1 && backgroundFrame.height <= 50.0 {
                cornerRadius = backgroundFrame.height * 0.5
            } else {
                cornerRadius = 20.0
            }
            
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: cornerRadius, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: component.preferClearGlass ? .clear : .panel), isInteractive: true, transition: transition)
            
            transition.setAlpha(view: self.backgroundContainer, alpha: (component.tabs != nil || !component.panels.isEmpty) ? 1.0 : 0.0)
            
            transition.setFrame(view: self.contentContainer, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            
            transition.setCornerRadius(layer: self.contentContainer.layer, cornerRadius: min(cornerRadius, backgroundFrame.height * 0.5))
            
            return size
        }
        
        private func updateClassicBackground(component: HeaderPanelContainerComponent, size: CGSize, transition: ComponentTransition) {
            let navigationBarTheme = component.theme.rootController.navigationBar
            
            self.backgroundContainer.isHidden = true
            
            let backgroundNode: NavigationBackgroundNode
            if let current = self.classicBackgroundNode {
                backgroundNode = current
            } else {
                backgroundNode = NavigationBackgroundNode(color: navigationBarTheme.blurredBackgroundColor, enableBlur: navigationBarTheme.blurredBackgroundColor.alpha < 1.0)
                backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 0.0))
                self.classicBackgroundNode = backgroundNode
                self.insertSubview(backgroundNode.view, at: 0)
            }
            let separatorLayer: SimpleLayer
            if let current = self.classicSeparatorLayer {
                separatorLayer = current
            } else {
                separatorLayer = SimpleLayer()
                separatorLayer.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: UIScreenPixel))
                self.classicSeparatorLayer = separatorLayer
                self.layer.addSublayer(separatorLayer)
            }
            
            if self.contentContainer.superview !== self {
                self.contentContainer.frame = CGRect(origin: CGPoint(), size: size)
                self.insertSubview(self.contentContainer, aboveSubview: backgroundNode.view)
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            backgroundNode.updateColor(color: navigationBarTheme.blurredBackgroundColor, enableBlur: navigationBarTheme.blurredBackgroundColor.alpha < 1.0, transition: .immediate)
            transition.setFrame(view: backgroundNode.view, frame: backgroundFrame)
            backgroundNode.update(size: backgroundFrame.size, transition: transition.containedViewLayoutTransition)
            
            separatorLayer.backgroundColor = navigationBarTheme.separatorColor.cgColor
            // Under the strip, as 12.0's bar drew its separator under the accessory panels it extended over.
            transition.setFrame(layer: separatorLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height), size: CGSize(width: size.width, height: UIScreenPixel)))
            transition.setAlpha(layer: separatorLayer, alpha: size.height > 0.0 ? 1.0 : 0.0)
            
            transition.setFrame(view: self.contentContainer, frame: backgroundFrame)
            transition.setCornerRadius(layer: self.contentContainer.layer, cornerRadius: 0.0)
        }
        
        private func updateClassicBare(size: CGSize, transition: ComponentTransition) {
            if let classicBackgroundNode = self.classicBackgroundNode {
                self.classicBackgroundNode = nil
                classicBackgroundNode.view.removeFromSuperview()
            }
            if let classicSeparatorLayer = self.classicSeparatorLayer {
                self.classicSeparatorLayer = nil
                classicSeparatorLayer.removeFromSuperlayer()
            }
            
            self.backgroundContainer.isHidden = true
            
            if self.contentContainer.superview !== self {
                self.contentContainer.frame = CGRect(origin: CGPoint(), size: size)
                self.insertSubview(self.contentContainer, at: 0)
            }
            
            transition.setFrame(view: self.contentContainer, frame: CGRect(origin: CGPoint(), size: size))
            transition.setCornerRadius(layer: self.contentContainer.layer, cornerRadius: 0.0)
        }
        
        private func removeClassicBackground() {
            if let classicBackgroundNode = self.classicBackgroundNode {
                self.classicBackgroundNode = nil
                classicBackgroundNode.view.removeFromSuperview()
            }
            if let classicSeparatorLayer = self.classicSeparatorLayer {
                self.classicSeparatorLayer = nil
                classicSeparatorLayer.removeFromSuperlayer()
            }
            self.backgroundContainer.isHidden = false
            if self.contentContainer.superview !== self.backgroundView.contentView {
                self.backgroundView.contentView.addSubview(self.contentContainer)
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
