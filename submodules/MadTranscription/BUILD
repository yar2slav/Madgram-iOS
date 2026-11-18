load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MadTranscription",
    module_name = "MadTranscription",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AccountContext",
        "//submodules/Media/ConvertOpusToAAC",
        "//submodules/Media/LocalAudioTranscription",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
