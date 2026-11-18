import Foundation
import TelegramCore

public enum MadLinkCleaner {
    private struct Provider {
        let host: NSRegularExpression
        let params: NSRegularExpression
        let paths: [NSRegularExpression]
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static func paramsRule(_ params: [String]) -> NSRegularExpression {
        return regex("^(?:" + params.joined(separator: "|") + ")$")
    }

    private static func matches(_ expression: NSRegularExpression, _ string: String) -> Bool {
        return expression.firstMatch(in: string, options: [], range: NSRange(location: 0, length: (string as NSString).length)) != nil
    }

    private static let globalRule = paramsRule([
        "utm(?:_[a-z_]*)?", "mtm_[a-z_]*",
        "pk_(?:campaign|kwd|keyword|source|medium|content|cid)",
        "ga_[a-z_]+", "_ga", "_gl", "gclid", "gclsrc",
        "gbraid", "wbraid", "dclid", "gad_source",
        "gad_campaignid", "fbclid", "fb_action_(?:ids|types)",
        "fb_(?:source|ref)", "action_(?:object|type|ref)_map",
        "msclkid", "twclid", "ttclid", "li_fat_id", "epik",
        "yclid", "ysclid", "_openstat", "mc_(?:cid|eid|tc)",
        "ml_subscriber(?:_hash)?", "mkt_tok", "igshid", "igsh",
        "_hsenc", "_hsmi", "__hsfp", "__hssc", "__hstc",
        "hsctatracking", "srsltid", "s_kwcid", "s_cid",
        "oly_(?:anon|enc)_id", "rb_clickid", "vero_(?:conv|id)",
        "wickedid", "_kx", "wt_?z?mc", "wtrid",
        "hmb_(?:campaign|medium|source)",
        "itm_(?:campaign|medium|source)", "otm_[a-z_]*", "cmpid",
        "os_ehash", "__twitter_impression", "tracking_source",
        "echobox", "spm", "_branch_match_id", "_branch_referrer",
        "si"
    ])

    private static let providers: [Provider] = {
        let data: [(String, [String], [String])] = [
            ("(?:^|\\.)(?:youtube\\.com|youtu\\.be|youtube-nocookie\\.com)$", ["feature", "pp", "kw"], []),
            ("(?:^|\\.)(?:spotify\\.com)$", ["context", "nd", "dl_branch"], []),
            ("(?:^|\\.)(?:twitter\\.com|x\\.com|fxtwitter\\.com|vxtwitter\\.com|fixupx\\.com|fixvx\\.com)$", ["s", "t", "src", "ref_src", "ref_url", "cn"], []),
            ("(?:^|\\.)(?:instagram\\.com)$", ["igshid", "igsh"], []),
            ("(?:^|\\.)(?:threads\\.net|threads\\.com)$", ["xmt", "slof"], []),
            ("(?:^|\\.)(?:tiktok\\.com)$", ["_r", "_t", "_d", "is_from_webapp", "is_copy_url", "sender_device", "sender_web_id", "web_id", "u_code", "preview_pb", "timestamp", "user_id", "share_app_name", "share_app_id", "share_iid", "share_link_id", "share_item_id", "social_share_type", "source", "checksum", "tt_from"], []),
            ("(?:^|\\.)(?:facebook\\.com|fb\\.com|fb\\.watch)$", ["mibextid", "rdid", "__tn__", "__cft__\\[\\d+\\]", "__xts__\\[\\d+\\]", "hc_[a-z_\\[\\]0-9]*", "eid", "ref", "fref", "refid", "refsrc", "ref_[a-z_]*", "comment_tracking", "notif_id", "notif_t", "sfnsn", "paipv", "eav", "dti", "_rdr", "rdr", "rdc", "wtsid", "acontext"], []),
            ("(?:^|\\.)(?:reddit\\.com)$", ["share_id", "ref", "ref_source", "ref_campaign", "correlation_id", "rdt", "\\$deep_link", "\\$3p", "\\$original_url"], []),
            ("(?:^|\\.)(?:amazon(?:\\.[a-z]{2,3}){1,2})$", ["p[fd]_rd_[a-z]*", "qid", "srs?", "__mk_[a-z]{1,3}_[a-z]{1,3}", "spia", "ms3_c", "ie", "refrid", "colii?d", "adid", "qualifier", "_encoding", "ref_?", "sprefix", "crid", "cv_ct_[a-z]+", "linkcode", "linkid", "tag", "creativeasin", "ascsubtag", "aaxitk", "hsa_cr_id", "sb-ci-[a-z]+", "dchild", "camp", "creative", "content-id", "dib", "dib_tag", "social_share", "starsleft", "skiptwisterog"], ["/ref=[^/]*"]),
            ("(?:^|\\.)(?:aliexpress(?:\\.[a-z]{2,3}){1,2})$", ["aff_[a-z_]*", "af", "afsmartredirect", "algo_expid", "algo_pvid", "btsid", "businesstype", "cv", "dp", "gps-id", "gatewayadapt", "mall_affr", "pdp_ext_f", "pdp_npi", "pdp_pi", "pvid", "scm[_a-z-]*", "sk", "social_params", "sourcetype", "spreadtype", "srcsns", "terminal_id", "tt", "ws_ab_test", "utparam-url"], []),
            ("(?:^|\\.)(?:vk\\.com|vk\\.ru|vkvideo\\.ru)$", ["from", "ref", "ref_domain"], []),
            ("(?:^|\\.)(?:yandex(?:\\.[a-z]{2,3}){1,2}|ya\\.ru)$", ["from", "clid", "redircnt"], []),
            ("^(?:www\\.)?google(?:\\.[a-z]{2,3}){1,2}$", ["ved", "ei", "sa", "usg", "oq", "aqs", "gs_[a-z]*", "sclient", "sxsrf", "sourceid", "uact", "bih", "biw", "dpr", "rlz", "iflsig", "sca_esv", "sca_upv", "fbs", "ictx", "cshid", "gws_rd", "source", "ie"], []),
            ("^(?:docs|drive)\\.google\\.com$", ["usp"], []),
            ("(?:^|\\.)(?:linkedin\\.com)$", ["trk", "trkinfo", "trackingid", "refid", "lipi", "licu", "midtoken", "midsig", "trkemail", "rcm"], []),
            ("(?:^|\\.)(?:ebay(?:\\.[a-z]{2,3}){1,2})$", ["_trkparms", "_trksid", "_from", "hash", "mkcid", "mkrid", "mkevt", "campid", "toolid", "customid", "amdata", "ssspo", "sssrc", "ssuid", "widget_ver", "itmmeta"], []),
            ("(?:^|\\.)(?:medium\\.com)$", ["source"], []),
            ("(?:^|\\.)(?:github\\.com)$", ["email_token", "email_source"], []),
            ("(?:^|\\.)(?:steampowered\\.com|steamcommunity\\.com)$", ["snr"], []),
            ("(?:^|\\.)(?:netflix\\.com)$", ["trackid", "tctx"], []),
            ("(?:^|\\.)(?:twitch\\.tv)$", ["tt_medium", "tt_content"], []),
            ("(?:^|\\.)(?:imdb\\.com)$", ["ref_", "pf_rd_[a-z]*"], []),
            ("(?:^|\\.)(?:bing\\.com)$", ["cvid", "form", "sk", "sp", "sc", "qs", "qp", "pq", "ghsh", "ghacc", "ghpl"], []),
            ("(?:^|\\.)(?:msn\\.com)$", ["ocid", "cvid"], []),
            ("(?:^|\\.)(?:apple\\.com)$", ["ign-itsc[a-z]+", "itscg", "itsct"], []),
            ("(?:^|\\.)(?:pinterest(?:\\.[a-z]{2,3}){1,2})$", ["invite_code", "sender", "sfo"], []),
            ("(?:^|\\.)(?:hh\\.ru)$", ["hhtmfrom", "hhtmfromlabel", "hhtmsource", "vss", "swnt", "grpos", "ptl", "stl", "exp", "plim"], []),
            ("(?:^|\\.)(?:ozon\\.ru)$", ["partner", "from"], [])
        ]
        return data.map { host, params, paths in
            return Provider(host: regex(host), params: paramsRule(params), paths: paths.map(regex))
        }
    }()

    private static let telegramHost = regex("(?:^|\\.)(?:t\\.me|telegram\\.me|telegram\\.dog)$")
    private static let httpScheme = regex("^https?://")
    private static let anyScheme = regex("^[a-z][a-z0-9+.\\-]*:(?!\\d)")

    private static func filterParams(_ list: String, rules: [NSRegularExpression]) -> (value: String, removed: Bool) {
        var removed = false
        var kept: [Substring] = []
        for part in list.split(separator: "&", omittingEmptySubsequences: true) {
            let rawName = String(part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
            let name = rawName.removingPercentEncoding ?? rawName
            if rules.contains(where: { matches($0, name) }) {
                removed = true
            } else {
                kept.append(part)
            }
        }
        return (kept.joined(separator: "&"), removed)
    }

    public static func clean(url: String) -> String {
        let ns = url as NSString
        guard let scheme = httpScheme.firstMatch(in: url, options: [], range: NSRange(location: 0, length: ns.length)) else {
            return url
        }
        let start = scheme.range.location + scheme.range.length
        var end = ns.length
        for character in ["/", "?", "#"] {
            let found = ns.range(of: character, options: [], range: NSRange(location: start, length: ns.length - start))
            if found.location != NSNotFound {
                end = min(end, found.location)
            }
        }
        var host = ns.substring(with: NSRange(location: start, length: end - start))
        if let at = host.lastIndex(of: "@") {
            host = String(host[host.index(after: at)...])
        }
        if host.hasPrefix("[") {
            return url
        }
        host = String(host.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).first ?? "").lowercased()
        while host.hasSuffix(".") {
            host.removeLast()
        }
        if host.isEmpty || matches(telegramHost, host) {
            return url
        }

        var rules: [NSRegularExpression] = [globalRule]
        var paths: [NSRegularExpression] = []
        for provider in providers where matches(provider.host, host) {
            rules.append(provider.params)
            paths.append(contentsOf: provider.paths)
        }

        let tail = NSRange(location: end, length: ns.length - end)
        let hashRange = ns.range(of: "#", options: [], range: tail)
        let hash: Int? = hashRange.location == NSNotFound ? nil : hashRange.location
        let beforeHash = hash ?? ns.length
        let questionRange = ns.range(of: "?", options: [], range: tail)
        let hasQuery = questionRange.location != NSNotFound && questionRange.location < beforeHash
        let pathEnd = hasQuery ? questionRange.location : beforeHash

        var path = ns.substring(with: NSRange(location: end, length: pathEnd - end))
        var query = hasQuery ? ns.substring(with: NSRange(location: questionRange.location + 1, length: beforeHash - questionRange.location - 1)) : ""
        var fragment = hash.flatMap { ns.substring(from: $0 + 1) } ?? ""
        var hasFragment = hash != nil
        var changed = false

        for rule in paths {
            let updated = rule.stringByReplacingMatches(in: path, options: [], range: NSRange(location: 0, length: (path as NSString).length), withTemplate: "")
            if updated != path {
                path = updated
                changed = true
            }
        }
        if hasQuery {
            let filtered = filterParams(query, rules: rules)
            if filtered.removed {
                query = filtered.value
                changed = true
            }
        }
        if hasFragment && fragment.contains("=") && !fragment.contains("/") {
            let filtered = filterParams(fragment, rules: rules)
            if filtered.removed {
                fragment = filtered.value
                hasFragment = !fragment.isEmpty
                changed = true
            }
        }
        if !changed {
            return url
        }
        var result = ns.substring(to: end) + path
        if !query.isEmpty {
            result += "?" + query
        }
        if hasFragment {
            result += "#" + fragment
        }
        return result
    }

    public static func cleanLoose(_ url: String) -> String {
        if matches(anyScheme, url) {
            return clean(url: url)
        }
        let prefixed = "http://" + url
        let result = clean(url: prefixed)
        return result == prefixed ? url : String(result.dropFirst(7))
    }

    private static func canReplace(_ range: NSRange, entities: [MessageTextEntity]) -> Bool {
        let start = range.location
        let end = range.location + range.length
        for entity in entities {
            let from = entity.range.lowerBound
            let till = entity.range.upperBound
            if till <= start || from >= end {
                continue
            }
            if from > start || till < end {
                return false
            }
            switch entity.type {
            case .Code, .Pre:
                return false
            default:
                break
            }
        }
        return true
    }

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    public static func clean(text: String, entities: [MessageTextEntity]) -> (text: String, entities: [MessageTextEntity]) {
        var entities = entities.map { entity -> MessageTextEntity in
            if case let .TextUrl(url) = entity.type {
                let cleaned = cleanLoose(url)
                if cleaned != url {
                    return MessageTextEntity(range: entity.range, type: .TextUrl(url: cleaned))
                }
            }
            return entity
        }
        let ns = text as NSString
        var ranges: [NSRange] = entities.compactMap { entity in
            if case .Url = entity.type {
                return NSRange(location: entity.range.lowerBound, length: entity.range.count)
            }
            return nil
        }
        if ranges.isEmpty, let detector {
            ranges = detector.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)).map(\.range)
        }
        var replacements: [MadTextReplacement] = []
        for range in ranges where range.location + range.length <= ns.length {
            if !canReplace(range, entities: entities) {
                continue
            }
            let original = ns.substring(with: range)
            let cleaned = cleanLoose(original)
            if cleaned != original {
                replacements.append(MadTextReplacement(range: range, value: cleaned))
            }
        }
        let result = MadTextEditing.apply(replacements, text: text, entities: entities)
        entities = result.entities
        return (result.text, entities)
    }
}
