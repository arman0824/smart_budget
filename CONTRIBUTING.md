# Contributing to Smart Budget

Thanks for helping improve Smart Budget. This guide covers the workflow and the
conventions the codebase follows.

## Prerequisites

- macOS with a full Xcode 26 installation (not just Command Line Tools)
- An iOS 26 / macOS 26 SDK, which ships with Xcode 26
- `git`, `make`, and optionally Docker for the Linux source check

## Build and test

```sh
# iOS build-for-testing, then macOS build + unit tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test
```

```sh
# On Linux (or without Xcode): validates the repository shape only
SOURCE_ONLY=1 make test
```

CI runs both on every push and pull request, so both must stay green.

## Project layout

```
app/                  SwiftUI app source (iOS, iPadOS, macOS)
  App/                AppStore (observable state, persistence orchestration)
  Components/         Design-system-adjacent reusable views
  Features/<Area>/    One folder per tab (Overview, Activity, Budgets, …)
  Models/             SwiftData models
  Persistence/        ModelContainerFactory (schema, seeding)
  Services/           FinancialCalculator, AmountParser, CSVExportService
  Theme/              DesignSystem (semantic colors, spacing, materials)
Tests/                XCTest suite (runs on macOS)
```

## Conventions that will get a PR merged quickly

- **User-entered amounts** go through `AmountParser` — never use `Decimal(string:)`
  on raw text. Display uses `MoneyTextValue`/`AmountParser.editingString`.
- **Colors** come from `DesignSystem.Colors` semantic tokens and must work in
  both the light and the dark appearance. Don't hard-code `#…` in views.
- **Views** use the `financialFormSurface()`, `financialFormSection()`,
  `financialPrimaryButton()`, and `financialSecondaryButton()` helpers instead of
  re-styling buttons and forms per screen.
- **SwiftData writes** go through `AppStore` (it refreshes `preferences` and
  persists). Don't call `context.save()` directly from views.
- Keep pull requests small and single-purpose: one fix or one feature per PR,
  committed as a series of `feat:`/`fix:`/`docs:` commits.

## Commit style

Conventional-commit prefixes, imperative subject line, e.g.
`fix: restore Quick Log contrast` or `feat: add appearance mode`.

## Reporting bugs and requesting features

Use the issue templates. For anything security-related, do **not** open a
public issue — see [SECURITY.md](SECURITY.md).
