load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "MadgramFeatureTestsLib",
    testonly = True,
    srcs = glob(["Tests/**/*.swift"]),
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/ChatExport:ChatExport",
        "//submodules/MadgramText:MadgramText",
        "//submodules/MadProfileLinks:MadProfileLinksCore",
    ],
)

ios_test_runner(
    name = "MadgramFeatureTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "MadgramFeatureTests",
    minimum_os_version = "13.0",
    runner = ":MadgramFeatureTestRunner",
    deps = [":MadgramFeatureTestsLib"],
    visibility = ["//visibility:public"],
)
