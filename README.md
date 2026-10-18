# Smart Budget

Smart Budget is a calm, local-first personal finance tracker for iPhone, iPad,
and Mac. Track spending, income, budgets, subscriptions, and financial trends
without an account or cloud backend.

## What the app does

- **Overview:** See your monthly balance, spending, income, budgets, and upcoming bills at a glance.
- **Activity:** Record expenses, income, refunds, and transfers with categories, dates, and notes.
- **Budgets:** Set category limits and understand how much room is left in each plan.
- **Subscriptions:** Keep recurring bills together and see their monthly and yearly cost.
- **Insights:** Explore spending over time, income versus spending, category totals, and useful comparisons.
- **Quick Log on macOS:** Add a transaction from the menu bar without opening the full app.

Everything is designed to be simple and private: financial records stay on the
device in SwiftData, and there is no sign-in, tracking, analytics SDK, or
server-side data store.

## Clone

```sh
git clone https://github.com/arman0824/smart_budget.git && cd smart_budget
```

## Build and use on macOS

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app.xcodeproj -scheme app -configuration Debug -sdk macosx -destination 'platform=macOS' -derivedDataPath .build/DerivedData-macOS CODE_SIGNING_ALLOWED=NO build && open .build/DerivedData-macOS/Build/Products/Debug/app.app
```

## Build and use on iPhone or iPad

```sh
open app.xcodeproj
```

Select the `app` scheme, choose an iPhone/iPad simulator or device, and press **Run**.

## Test

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test
```

## Linux source check

```sh
docker build --tag smart-budget-source-check . && docker run --rm smart-budget-source-check
```

## Archive for distribution

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app.xcodeproj -scheme app -configuration Release -destination 'generic/platform=iOS' -archivePath .build/SmartBudget.xcarchive archive
```

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -exportArchive -archivePath .build/SmartBudget.xcarchive -exportOptionsPlist /path/to/ExportOptions.plist -exportPath .build/export
```
