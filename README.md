# Smart Budget & Subscription Tracker

Smart Budget & Subscription Tracker is a native SwiftUI iOS app organized
around a local-first domain model. `ContentView` routes into onboarding or the
five-tab finance experience.

## Architecture

- `app/MyApp.swift` creates the shared SwiftData container and
  `app/ContentView.swift` routes into the app shell.
- On macOS, `MyApp` also exposes a native **Quick Log** menu bar item. Its
  compact popover records an expense, income, refund, or transfer without
  opening the main window, while sharing the same local SwiftData store.
- `app/Models/` contains SwiftData models for transactions, categories,
  budgets, subscriptions, and preferences.
- `app/Persistence/ModelContainerFactory.swift` defines the SwiftData schema,
  creates a disk-backed `ModelContainer` by default, and can create an
  in-memory container for checks. Default categories and preferences are
  seeded without generating transactions.
- `app/Services/FinancialCalculator.swift` contains deterministic summaries,
  budget status, subscription equivalents, and insights.
- `app/Services/SubscriptionNotificationService.swift` schedules local
  `UserNotifications` reminders. `CSVExportService.swift` provides a user-
  initiated CSV `FileDocument` export.

There is no backend, network service, analytics SDK, or third-party package.
The persistence layer is local-first: data remains on the device in SwiftData.
The Swift Package Manager resolution file is intentionally empty because the
project has no external package dependencies.
`Tests/FinancialCalculatorTests.swift` covers core money, budget, billing-date,
CSV, and persistence bootstrap behavior in the `appTests` XCTest target.

## Supported toolchain and target

- macOS with **Xcode 27.0 or a compatible newer Xcode**. The project records
  `CreatedOnToolsVersion = 26.3`, `LastUpgradeCheck = 2700`, and
  `SWIFT_VERSION = 5.0`.
- The app supports iOS/iPadOS and native macOS. The iOS deployment target is
  **iOS 27.0** and the macOS deployment target is **macOS 27.0**. Platform-only
  SwiftUI controls use conditional implementations where needed.
- Xcode is required to build or run the Apple-platform app. Linux cannot build
  SwiftUI, SwiftData, or the Apple application SDKs.

## Setup and run

1. Install a compatible Xcode release and its iOS simulator runtime.
2. Confirm the selected developer directory (use an absolute path appropriate
   to the machine; do not commit it):

   ```sh
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version
   ```

3. Open the project, select the `app` scheme and choose an iOS Simulator,
   iOS device, or **My Mac**, then press **Run**:

   ```sh
   open app.xcodeproj
   ```

   On macOS, look for the **plus-circle** Quick Log icon in the menu bar. Use
   it to enter a transaction directly; **Open Smart Budget** opens the full
   app when a longer workflow is needed.

For a command-line compile smoke check for iOS, use the same developer directory:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project app.xcodeproj -scheme app -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

For a native macOS build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project app.xcodeproj -scheme app -configuration Debug \
  -sdk macosx -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

## Checks

`make test` compiles the app and XCTest bundle for a generic iOS Simulator and
runs the XCTest bundle on the native macOS target, without code signing. This
offline check is the repository's single reproducible test command; it does
not need a booted iOS Simulator.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test
```

Without a full Xcode developer directory, `make test` exits nonzero with a
message explaining how to select one. To execute the XCTest methods rather
than only compile them, run the `app` scheme's Test action in Xcode with an
available iOS 27 simulator or device. This checkout has no simulator devices
registered, so automated iOS test execution is not claimed here. Docker runs
the same target in its explicit Linux source-validation mode; it validates
repository structure and key project settings, but deliberately skips Apple
platform builds:

```sh
docker build --tag smart-budget-source-check .
docker run --rm smart-budget-source-check
```

## Privacy and notifications

Financial records are local-first and are not uploaded by this project. CSV
export is user initiated. The app does not currently provide cloud sync,
account recovery, server backup, or additional application-level encryption;
protect the device and exported files accordingly.

Reminders use the device's local notification center. They require user
permission, apply only to active subscriptions with notifications enabled, and
may be removed or delayed by iOS settings, Focus, power, or OS scheduling.
Denied permission or a disabled preference leaves no pending reminder. There
is no server-side notification fallback.

## Deploy

Configure the signing team and provisioning in Xcode, then archive and export
from the Organizer, or use the equivalent commands below with a local
`ExportOptions.plist` supplied by the signing workflow:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project app.xcodeproj -scheme app -configuration Release \
  -destination 'generic/platform=iOS' -archivePath .build/SmartBudget.xcarchive \
  archive

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -exportArchive -archivePath .build/SmartBudget.xcarchive \
  -exportOptionsPlist /path/to/ExportOptions.plist -exportPath .build/export
```

The exported archive can then be uploaded through Xcode Organizer or the
team's approved App Store Connect workflow. Do not commit signing files,
certificates, provisioning profiles, or credentials.
