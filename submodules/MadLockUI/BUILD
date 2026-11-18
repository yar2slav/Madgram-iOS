load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MadLockUI",
    module_name = "MadLockUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
    ],
    visibility = [
        "//visibility:public",
    ],
)
