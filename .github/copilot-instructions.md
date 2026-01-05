# Copilot instructions

## Architecture overview
- The entry flow in [lib/main.dart](lib/main.dart) is the single place that configures sqflite FFI on desktop, initializes `PrefsService`, primes pt_BR formatting, runs `DatabaseInitializationService`, and shows either `HomeScreen` or the migration fallback (`lib/screens/database_migration_screen.dart`). It also watches the app lifecycle so `BackupService` runs before the process detaches.
- `HomeScreen` relies on the `IndexedStack` defined in [lib/screens/home_screen.dart](lib/screens/home_screen.dart) to keep every tab alive; it lazy-loads the seven tabs and listens to `PrefsService.tabRequestNotifier` when code needs to jump to Database (index 6) or any other screen.

## Services and data flow
- [lib/services/prefs_service.dart](lib/services/prefs_service.dart) is the single source of truth for theme, region/city selection, date range, tab requests, and database protection preferences; every setter must persist to `SharedPreferences` and update the related `ValueNotifier` (e.g., `themeNotifier`, `cityNotifier`, `dateRangeNotifier`, `tabRequestNotifier`, `autoBackupEnabled`).
- [lib/database/db_helper.dart](lib/database/db_helper.dart) defines `finance_v62.db`, configures PRAGMAs, creates indexes, and houses all `_upgradeDB` logic; new schema changes must be appended there and the migration path should call `[lib/services/database_protection_service.dart](lib/services/database_protection_service.dart)` so a checksum backup happens before the destructive upgrade.
- After `DatabaseInitializationService` populates the basic schema, it pulls default categories and subcategories from `[lib/services/default_account_categories_service.dart](lib/services/default_account_categories_service.dart)` and the standard payment methods defined in `populatePaymentMethods`; this is the core source for seeded data so reuse it when adding new defaults.
- `[lib/services/database_migration_service.dart](lib/services/database_migration_service.dart)` wraps the sqflite onUpgrade with a `MigrationStatus` `ValueNotifier`; the UI consumes it inside `[lib/screens/database_migration_screen.dart](lib/screens/database_migration_screen.dart)` so any long-running upgrade should update that notifier before/after validation.

## UI and integration patterns
- `[lib/screens/settings_screen.dart](lib/screens/settings_screen.dart)` feels for `PrefsService.cityNotifier` and `themeNotifier` in `initState`, uses `HolidayService.regions` (`lib/services/holiday_service.dart`) to populate and sort the city list, and saves selections via `PrefsService.saveLocation`; the city dialog keeps its own search state so reuse that pattern when building modal pickers.
- `SettingsScreen` toggles `PrefsService.tabRequestNotifier` to `6` when the user taps "Banco de dados" so the home tab controller opens `[lib/screens/database_screen.dart](lib/screens/database_screen.dart)`; piggyback on the same notifier when you need programmatic tab switches.
- Logging across services intentionally uses emoji-prefixed messages (🚀 for app lifecycle, 🔧 for services, 🏠 for screens, etc.) because the debug workflow in `[DEBUG_GUIDE.md](DEBUG_GUIDE.md)` and `[DEBUG_SUMMARY.txt](DEBUG_SUMMARY.txt)` expects those markers; new debug prints should follow that style so the freeze tracker can identify progress.

## Backup, protection, and recovery
- `[lib/services/backup_service.dart](lib/services/backup_service.dart)` is called on app detach (`AppLifecycleState.detached`) and uses `DatabaseHelper` to copy the live DB, keep the ten newest files, and allow manual restoration; use the same helpers when exposing backups elsewhere.
- `[lib/services/database_protection_service.dart](lib/services/database_protection_service.dart)` writes backups to `ContasLite/Backups`, calculates SHA-256, tracks metadata JSON, rotates to five copies, and performs integrity checks (PRAGMA integrity_check, foreign_key_check, orphan detection) before migrations; hook into that service before any destructive operation in `db_helper` or `DatabaseMigrationService`.
- `BackupService`, `DatabaseProtectionService`, and `DatabaseHelper` all expect the `finance_v62.db` name in the application documents folder, so avoid renaming the file without updating every reference.

## Workflows and debugging
- To reproduce the Preferences freeze, follow the steps in `[DEBUG_GUIDE.md](DEBUG_GUIDE.md)` and `[INSTRUÇÕES_DEBUG.md](INSTRUÇÕES_DEBUG.md)`: run `flutter run -v | Tee-Object -FilePath debug_logs.txt` (PowerShell) or `flutter run -v > debug_logs.txt 2>&1` (cmd), wait for the emoji-rich logs, click the gear, and stop with `Ctrl+C`; the last 50 lines will show exactly whether the hang stops at `HomeScreen.initState` or `SettingsScreen.initState` as summarized in `[DEBUG_SUMMARY.txt](DEBUG_SUMMARY.txt)`.
- Keep `flutter analyze` and `flutter test` (runs `test/widget_test.dart` plus `holiday_loading_test.dart`) in your routine before committing changes; the project honors `analysis_options.yaml` so fix lints that are surfaced there.
- When adding diagnostics, reuse the emoji prefixes (`🚀`, `🔧`, `🗂️`, etc.) because automated triage scripts expect those keywords to locate the log point noted in the debug guides.

## Feedback request
- Please let me know if any area above is unclear or missing context so I can iterate on these instructions.