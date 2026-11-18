load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MadgramAgentUI",
    module_name = "MadgramAgentUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AccountContext",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/ItemListUI",
        "//submodules/ChatInterfaceState",
        "//submodules/Media/ConvertOpusToAAC",
        "//submodules/Media/LocalAudioTranscription",
        "//submodules/LocalizedPeerData",
        "//submodules/MadgramAgent",
        "//submodules/MadgramText",
        "//submodules/PresentationDataUtils",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
