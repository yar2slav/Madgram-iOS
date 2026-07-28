load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerBadgeUI",
    module_name = "PeerBadgeUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext:AccountContext",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Display:Display",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/TelegramUI/Components/EmojiStatusComponent:EmojiStatusComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
