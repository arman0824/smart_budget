# Smart Budget & Subscription Tracker

Smart Budget & Subscription Tracker is a SwiftUI iOS app organized around a
local-first domain model. The repository currently contains the data and
service layers; `ContentView` is the SwiftUI entry view.

## Architecture

- `app/MyApp.swift` is the application entry point and `app/ContentView.swift`
  is the current view-layer entry point.
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
The persistence layer is local-first: data is intended to remain on the
device in SwiftData. The current root view has not yet injected the container
into the view hierarchy; that wiring belongs in `MyApp` when the UI is
connected to the models.

## Supported toolchain and target

- macOS with **Xcode 27.0 or a compatible newer Xcode**. The project records
  `CreatedOnToolsVersion = 26.3`, `LastUpgradeCheck = 2700`, and
  `SWIFT_VERSION = 5.0`.
- The primary build path is `iphoneos`/`iphonesimulator` with an
  `IPHONEOS_DEPLOYMENT_TARGET` of **iOS 27.0**. The project file also lists
  macOS and visionOS platforms; this repository's checks target iOS.
- Xcode is required to build or run the iOS app. Linux cannot build SwiftUI,
  SwiftData, or the iOS application SDK.

## Setup and run

1. Install a compatible Xcode release and its iOS simulator runtime.
2. Confirm the selected developer directory (use an absolute path appropriate
   to the machine; do not commit it):

   ```sh
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version
   ```

3. Open the project, select the `app` scheme and an iOS Simulator or device,
   then press **Run**:

   ```sh
   open app.xcodeproj
   ```

For a command-line compile smoke check, use the same developer directory:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project app.xcodeproj -scheme app -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Checks

The repository has no XCTest bundle yet. `make test` therefore performs the
meaningful available check: it compiles the app for a generic iOS Simulator
without code signing.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test
```

Without a full Xcode developer directory, `make test` exits nonzero with a
message explaining how to select one. Docker runs the same target in its
explicit Linux source-validation mode; it validates repository structure and
key project settings, but deliberately skips the iOS build:

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
