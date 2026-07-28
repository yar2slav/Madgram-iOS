load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "MessageFilterTestsLib",
    testonly = True,
    srcs = glob(["Tests/**/*.swift"]),
    deps = [
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
    ],
)

ios_test_runner(
    name = "MessageFilterTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "MessageFilterTests",
    minimum_os_version = "13.0",
    runner = ":MessageFilterTestRunner",
    deps = [":MessageFilterTestsLib"],
    visibility = ["//visibility:public"],
)
