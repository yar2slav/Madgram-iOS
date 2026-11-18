load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MadProfileLinksCore",
    module_name = "MadProfileLinksCore",
    srcs = glob([
        "Core/**/*.swift",
    ]),
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "MadProfileLinks",
    module_name = "MadProfileLinks",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        ":MadProfileLinksCore",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/PresentationDataUtils",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
