import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SegmentedControlNode

/// Madgram: the map-mode strip of Telegram 12.0 (`LocationOptionsNode`, removed upstream with Liquid Glass): a
/// Map / Satellite / Hybrid segmented control on a bar-coloured strip that slides out from under the navigation
/// bar. Used by the location picker only while `ClassicDesign.isEnabled`.
final class ClassicLocationOptionsNode: ASDisplayNode {
    private var presentationData: PresentationData

    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let segmentedControlNode: SegmentedControlNode

    init(presentationData: PresentationData, updateMapMode: @escaping (LocationMapMode) -> Void) {
        self.presentationData = presentationData

        self.backgroundNode = NavigationBackgroundNode(color: presentationData.theme.rootController.navigationBar.blurredBackgroundColor)
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor

        self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: presentationData.theme), items: [SegmentedControlItem(title: presentationData.strings.Map_Map), SegmentedControlItem(title: presentationData.strings.Map_Satellite), SegmentedControlItem(title: presentationData.strings.Map_Hybrid)], selectedIndex: 0)

        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.segmentedControlNode)

        self.segmentedControlNode.selectedIndexChanged = { index in
            switch index {
            case 0:
                updateMapMode(.map)
            case 1:
                updateMapMode(.satellite)
            case 2:
                updateMapMode(.hybrid)
            default:
                break
            }
        }
    }

    func updateMapMode(_ mapMode: LocationMapMode) {
        let index: Int
        switch mapMode {
        case .map:
            index = 0
        case .satellite:
            index = 1
        case .hybrid:
            index = 2
        }
        if self.segmentedControlNode.selectedIndex != index {
            self.segmentedControlNode.selectedIndex = index
        }
    }

    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.backgroundNode.updateColor(color: presentationData.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
        self.separatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        self.segmentedControlNode.updateTheme(SegmentedControlTheme(theme: presentationData.theme))
    }

    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundNode.update(size: size, transition: transition)

        transition.updateFrame(node: self.separatorNode, frame: CGRect(x: 0.0, y: size.height, width: size.width, height: UIScreenPixel))

        let controlSize = self.segmentedControlNode.updateLayout(.stretchToFill(width: size.width - 16.0 - leftInset - rightInset), transition: .immediate)
        self.segmentedControlNode.frame = CGRect(origin: CGPoint(x: floor((size.width - controlSize.width) / 2.0), y: 0.0), size: controlSize)
    }
}
