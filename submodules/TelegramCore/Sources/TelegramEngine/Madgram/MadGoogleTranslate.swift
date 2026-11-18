import Foundation
import SwiftSignalKit

public enum MadGoogleTranslate {
    private static func normalizedLanguage(_ code: String) -> String {
        var value = code
        if value.hasSuffix("-raw") {
            value = String(value.dropLast(4))
        }
        switch value {
        case "zh-hans":
            return "zh-CN"
        case "zh-hant":
            return "zh-TW"
        default:
            return value
        }
    }

    public static func translate(text: String, toLang: String) -> Signal<String?, NoError> {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .single(text)
        }
        return Signal { subscriber in
            var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
            components.queryItems = [
                URLQueryItem(name: "client", value: "gtx"),
                URLQueryItem(name: "sl", value: "auto"),
                URLQueryItem(name: "tl", value: normalizedLanguage(toLang)),
                URLQueryItem(name: "dt", value: "t")
            ]
            var request = URLRequest(url: components.url!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            request.httpBody = ("q=" + (text.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")).data(using: .utf8)
            request.timeoutInterval = 20.0
            let task = URLSession.shared.dataTask(with: request, completionHandler: { data, _, _ in
                guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [Any], let sentences = json.first as? [Any] else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                var result = ""
                for sentence in sentences {
                    if let parts = sentence as? [Any], let piece = parts.first as? String {
                        result += piece
                    }
                }
                subscriber.putNext(result.isEmpty ? nil : result)
                subscriber.putCompletion()
            })
            task.resume()
            return ActionDisposable {
                task.cancel()
            }
        }
    }

    public static func translate(texts: [AnyHashable: String], toLang: String) -> Signal<[AnyHashable: String]?, NoError> {
        let keys = Array(texts.keys)
        if keys.isEmpty {
            return .single([:])
        }
        return combineLatest(keys.map { key in
            return translate(text: texts[key] ?? "", toLang: toLang)
        })
        |> map { values -> [AnyHashable: String]? in
            var result: [AnyHashable: String] = [:]
            for (index, key) in keys.enumerated() {
                guard let value = values[index] else {
                    return nil
                }
                result[key] = value
            }
            return result
        }
    }
}
