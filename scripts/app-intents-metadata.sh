#!/bin/sh
# Regenerates Assets/Metadata.appintents, which lets macOS find Squint's App Intents (Spotlight, Siri, Shortcuts).
# Xcode makes this file only for app targets, not Swift-package executables, so this script runs the same two steps:
# the compiler extracts constant values from the sources, then Apple's processor exports the metadata.
# Needs Xcode (not only the Command Line Tools). Run after changing anything in Sources/Squint/App/Intents.
set -eu
cd "$(dirname "$0")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

sdk="$(xcrun --show-sdk-path)"
toolchain="$(dirname "$(dirname "$(dirname "$(xcrun --find swiftc)")")")"
xcode_build="$(xcodebuild -version | awk '/Build version/ { print $3 }')"
find "$PWD/Sources/Squint" -name '*.swift' | sort > "$work/sources.txt"
echo "$work/Squint.swiftconstvalues" > "$work/constvalues.txt"
printf '["AppIntent","EntityQuery","AppEntity","TransientEntity","AppEnum","AppShortcutsProvider","DynamicOptionsProvider"]' > "$work/protocols.json"

# shellcheck disable=SC2046 # one argument per source file
xcrun swiftc -module-name Squint -sdk "$sdk" -target arm64-apple-macos14.0 -swift-version 6 -wmo -typecheck \
    -emit-const-values-path "$work/Squint.swiftconstvalues" \
    -Xfrontend -const-gather-protocols-file -Xfrontend "$work/protocols.json" \
    $(cat "$work/sources.txt")

xcrun appintentsmetadataprocessor --output "$work/out" --toolchain-dir "$toolchain" --module-name Squint \
    --sdk-root "$sdk" --xcode-version "$xcode_build" --platform-family macOS --deployment-target 14.0 \
    --target-triple arm64-apple-macos14.0 --source-file-list "$work/sources.txt" \
    --swift-const-vals-list "$work/constvalues.txt" --force --no-app-shortcuts-localization

rm -rf Assets/Metadata.appintents
cp -R "$work/out/Metadata.appintents" Assets/
echo "Assets/Metadata.appintents"
