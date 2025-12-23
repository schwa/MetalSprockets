# XCODE_PROJECT_PATH := "./Demo/MetalSprocketsDemo.xcodeproj"
XCODE_SCHEME := "MetalSprocketsDemo"
CONFIGURATION := "Debug"

default: list

list:
    just --list

build:
    swift build --quiet

test:
    swift test --quiet

coverage-percent:
    swift test --enable-code-coverage --quiet
    #.build/arm64-apple-macosx/debug/codecov/MetalSprockets.json
    xcrun llvm-cov report \
        .build/arm64-apple-macosx/debug/MetalSprocketsPackageTests.xctest/Contents/MacOS/MetalSprocketsPackageTests \
        -instr-profile=.build/arm64-apple-macosx/debug/codecov/default.profdata \
        -ignore-filename-regex=".build|Tests|MetalSprocketsExamples|MetalSprocketsGaussianSplats|MetalSprocketsSupport|MetalSprocketsUI" \
        | tail -1 | grep -oE '[0-9]+\.[0-9]+%' | head -n1

lint:
    swiftlint lint --quiet

format:
    swiftlint --fix --format --quiet
    fd --extension metal --extension h --exec clang-format -i {}

open-container:
    open "$HOME/Library/Containers/io.schwa.MetalSprocketsExamples/Data"

clean:
    swift package clean
    rm -rf .build
    rm -rf .swiftpm
    rm -rf Sources/MetalSprockets/.swiftpm/
    rm -rf MetalSprockets-Examples/MetalSprockets-Examples.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/

convert-docs:
    swift package \
        generate-documentation \
        --target MetalSprockets \
        --target MetalSprocketsUI \
        --enable-experimental-combined-documentation \
        --source-service github \
        --source-service-base-url https://github.com/schwa/MetalSprockets/blob/main \
        --checkout-path . \
        --transform-for-static-hosting \
        --output-path /tmp/MetalSprockets
