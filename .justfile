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

preview-docs target="MetalSprockets":
    swift package \
        --disable-sandbox \
        preview-documentation \
        --target {{target}}

generate-doccarchive:
    swift package \
        --disable-sandbox \
        generate-documentation \
        --target MetalSprockets \
        --target MetalSprocketsUI \
        --enable-experimental-combined-documentation \
        --source-service github \
        --source-service-base-url https://github.com/schwa/MetalSprockets/blob/main \
        --checkout-path . \
        --output-path /tmp/MetalSprockets.doccarchive

check-docs: generate-doccarchive
    lychee '/tmp/MetalSprockets.doccarchive/**/*.json' --verbose --scheme https --scheme http

list-external-links: generate-doccarchive
    lychee '/tmp/MetalSprockets.doccarchive/**/*.json' --scheme https --scheme http --verbose 2>&1 | grep -oE 'https?://[^ |]+' | sort -u

check-docs-diagnostics:
    #!/usr/bin/env bash
    for target in MetalSprockets MetalSprocketsUI; do
        swift package --disable-sandbox generate-documentation \
            --target "$target" \
            --diagnostics-file /tmp/docc-diagnostics.json \
            --output-path /tmp/MetalSprockets.doccarchive >/dev/null 2>&1
        jq -r '.diagnostics[] | if .source then "\(.source | sub("file://"; "")):\(.range.start.line): \(.summary)" else "\(.summary)" end' /tmp/docc-diagnostics.json 2>/dev/null
    done
