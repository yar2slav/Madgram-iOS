import Foundation
import UIKit
import Display

/// Madgram: the profile and Settings row metrics of Telegram 12.0, the look before Liquid Glass, used while
/// `ClassicDesign.isEnabled`. With the switch off each value is exactly the metric the glass rows use today.
enum PeerInfoClassicMetrics {
    static var isEnabled: Bool {
        return ClassicDesign.isEnabled
    }

    /// The padding above and below a one-line row's text: 12 in 12.0 (a 44 pt row at the 17 pt list font), 16 with
    /// glass (52 pt rows).
    static var rowVerticalInset: CGFloat {
        return isEnabled ? 12.0 : 16.0
    }

    /// A row's leading settings icon: 29 pt in 12.0, 30 pt with glass.
    static var rowIconSize: CGFloat {
        return isEnabled ? 29.0 : 30.0
    }

    /// A row separator runs to the section's trailing edge in 12.0; glass stops it 16 pt short.
    static var separatorRightInset: CGFloat {
        return isEnabled ? 0.0 : 16.0
    }

    /// The rounded background a row gets while it is extracted into a context menu: diameter 28 in 12.0, 52 with glass.
    static var extractedBackgroundDiameter: CGFloat {
        return isEnabled ? 28.0 : 52.0
    }

    /// The top (and bottom) padding of a multi-line labeled value: 11 in 12.0, 15 with glass.
    static var labeledValueVerticalInset: CGFloat {
        return isEnabled ? 11.0 : 15.0
    }

    /// The profile header's action buttons (Message, Mute, Call, ...): 11 pt corners in 12.0, 16 pt with glass.
    static var headerButtonCornerRadius: CGFloat {
        return isEnabled ? 11.0 : 16.0
    }

    /// The editing screen's name and bio fields: 11 pt padding in 12.0, 15 pt with glass.
    static var editingFieldVerticalInset: CGFloat {
        return isEnabled ? 11.0 : 15.0
    }
}
