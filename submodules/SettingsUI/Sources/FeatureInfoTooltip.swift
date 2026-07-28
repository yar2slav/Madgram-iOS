import ComponentFlow
import Display
import TelegramPresentationData
import UIKit

func featureInfoIcon(color: UIColor) -> UIImage? {
    let configuration = UIImage.SymbolConfiguration(pointSize: 16.0, weight: .regular)
    return UIImage(systemName: "info.circle", withConfiguration: configuration)?.withTintColor(color, renderingMode: .alwaysOriginal)
}

func featureInfoBadgeComponent(color: UIColor) -> AnyComponent<Empty>? {
    guard let image = featureInfoIcon(color: color) else {
        return nil
    }
    return AnyComponent(Image(image: image, size: CGSize(width: 18.0, height: 18.0), contentMode: .scaleAspectFit))
}

func presentFeatureInfoTooltip(
    text: String,
    sourceView: UIView,
    presentationData: PresentationData,
    controller: ViewController
) -> TooltipController {
    let tooltipController = TooltipController(
        content: .text(text),
        baseFontSize: presentationData.listsFontSize.baseDisplaySize,
        balancedTextLayout: true,
        alignment: .natural,
        isBlurred: true,
        timeout: 4.5,
        dismissByTapOutside: true,
        dismissByTapOutsideSource: true,
        dismissImmediatelyOnLayoutUpdate: true,
        padding: 16.0
    )
    controller.present(
        tooltipController,
        in: .window(.root),
        with: TooltipControllerPresentationArguments(sourceViewAndRect: { [weak sourceView] in
            guard let sourceView, sourceView.window != nil else {
                return nil
            }
            return (sourceView, sourceView.bounds)
        })
    )
    return tooltipController
}
