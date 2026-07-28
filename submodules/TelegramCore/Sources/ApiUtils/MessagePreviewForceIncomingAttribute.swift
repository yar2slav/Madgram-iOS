import Foundation
import Postbox

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
