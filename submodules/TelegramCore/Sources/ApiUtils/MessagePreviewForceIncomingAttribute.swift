import Foundation
import Postbox

/// Transient rendering metadata for preview surfaces that present a message as
/// a quoted incoming message while retaining its real author.
///
/// This attribute is never persisted in Postbox.
public final class MessagePreviewForceIncomingAttribute: MessageAttribute {
    public init() {
    }

    public init(decoder: PostboxDecoder) {
        preconditionFailure()
    }

    public func encode(_ encoder: PostboxEncoder) {
        preconditionFailure()
    }
}
