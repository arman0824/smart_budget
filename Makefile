.PHONY: test

PROJECT := app.xcodeproj
SCHEME := app
DERIVED_DATA_PATH ?= .build/DerivedData

test:
	@set -eu; \
	if [ "$${SOURCE_ONLY:-0}" = "1" ]; then \
		for path in \
			"$(PROJECT)/project.pbxproj" \
			"app/MyApp.swift" \
			"app/ContentView.swift" \
			"app/Persistence/ModelContainerFactory.swift" \
			"README.md" \
			"Makefile" \
			"Dockerfile"; do \
			test -f "$$path" || { printf '%s\n' "Missing required source file: $$path" >&2; exit 1; }; \
		done; \
		grep -q 'IPHONEOS_DEPLOYMENT_TARGET = 27.0;' "$(PROJECT)/project.pbxproj" || { printf '%s\n' 'Expected iOS deployment target is missing.' >&2; exit 1; }; \
		grep -q 'SWIFT_VERSION = 5.0;' "$(PROJECT)/project.pbxproj" || { printf '%s\n' 'Expected Swift language version is missing.' >&2; exit 1; }; \
		grep -q 'import SwiftData' app/Persistence/ModelContainerFactory.swift || { printf '%s\n' 'SwiftData persistence source is missing.' >&2; exit 1; }; \
		printf '%s\n' 'Linux source validation passed; the iOS build was intentionally skipped.'; \
		exit 0; \
	fi; \
	developer_dir="$${DEVELOPER_DIR:-$$(xcode-select -p 2>/dev/null || true)}"; \
	if [ -z "$$developer_dir" ] || [ ! -d "$$developer_dir" ] || ! DEVELOPER_DIR="$$developer_dir" xcodebuild -version >/dev/null 2>&1; then \
		printf '%s\n' 'Xcode is required for make test. Set DEVELOPER_DIR to a full Xcode Developer directory, for example /Applications/Xcode.app/Contents/Developer.' >&2; \
		exit 1; \
	fi; \
	DEVELOPER_DIR="$$developer_dir" xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Debug \
		-sdk iphonesimulator \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		CODE_SIGNING_ALLOWED=NO \
		build
