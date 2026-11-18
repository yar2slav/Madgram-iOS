import Foundation

public enum MadFlags {
    private static func settings() -> [String: Any]? {
        guard let data = UserDefaults.standard.data(forKey: "interfaceTuningSettings.v1") else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    public static func bool(_ key: String) -> Bool {
        return settings()?[key] as? Bool ?? false
    }

    public static func int(_ key: String, default defaultValue: Int) -> Int {
        if let value = settings()?[key] as? NSNumber {
            return value.intValue
        }
        return defaultValue
    }

    public static var cameraMaxDimensions: (width: Int32, height: Int32)? {
        switch int("cameraResolution", default: 1080) {
        case 2160:
            return (3840, 2160)
        case 720:
            return (1280, 720)
        default:
            return nil
        }
    }

    public static var cameraFrameRate: Double {
        return int("cameraFrameRate", default: 30) == 60 ? 60.0 : 30.0
    }

    public static var roundVideoUltraWide: Bool {
        return bool("roundVideoUltraWide")
    }

    public static var roundVideoBitrateMultiplier: Int {
        switch int("roundVideoQuality", default: 0) {
        case 1:
            return 2
        case 2:
            return 4
        default:
            return 1
        }
    }
}
