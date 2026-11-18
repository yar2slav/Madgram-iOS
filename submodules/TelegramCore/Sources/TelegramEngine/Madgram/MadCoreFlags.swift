import Foundation

public enum MadCoreFlags {
    private static func interfaceValue(_ key: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "interfaceTuningSettings.v1"), let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return false
        }
        return object[key] as? Bool ?? false
    }

    public static var sendInlineWithoutVia: Bool {
        return interfaceValue("sendInlineWithoutVia")
    }

    public static var freeTranslation: Bool {
        return interfaceValue("freeTranslation")
    }
}
