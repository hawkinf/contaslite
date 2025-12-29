# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Contas a Pagar** is a Flutter financial management application that works across desktop, mobile, and web platforms. It's a local-first app that persists data in SQLite and specializes in managing bills, credit cards, installments, and recurring expenses with Brazilian banking holiday support.

## Development Commands

### Installation and Setup
```bash
flutter pub get
```

### Run Application
```bash
flutter run -d windows    # Windows desktop
flutter run -d linux      # Linux desktop
flutter run -d macos      # macOS desktop
flutter run               # Android/iOS (with device connected)
flutter run -d chrome     # Web
```

### Build for Production
```bash
flutter build windows --release
flutter build linux --release
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
flutter build web --release
```

### Testing and Linting
```bash
flutter test              # Run all tests
flutter analyze           # Run static analysis
flutter clean             # Clean build artifacts
```

### Desktop Platform Setup
Enable desktop support if needed:
```bash
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
```

## Architecture Overview

### Core Architecture Pattern

The app follows a straightforward Flutter architecture without heavy state management frameworks:
- **UI Layer**: Screens in `lib/screens/` and reusable widgets in `lib/widgets/`
- **Data Models**: Plain Dart classes in `lib/models/` with `toMap()`/`fromMap()` serialization and `copyWith()` patterns
- **Business Logic**: Services in `lib/services/` handle cross-cutting concerns (preferences, holidays)
- **Persistence**: Single `DatabaseHelper` singleton in `lib/database/db_helper.dart` manages all SQLite operations
- **State Management**: Lightweight approach using `ValueNotifier` and `ChangeNotifier` for reactive UI updates

### Database Architecture

The app uses SQLite (`sqflite` + `sqflite_common_ffi` for desktop) with a single database file: `finance_v62.db`

**Critical Tables:**
- `accounts`: Main table storing both bills and credit cards (discriminated by `cardBrand` field)
- `account_types`: Categories like "Cartões de Crédito", "Consumo", "Saúde"
- `expense_categories`: User-defined expense categories for detailed tracking

**Key Fields in `accounts` table:**
- `purchaseUuid`: Groups related installments from a single purchase (critical for batch operations)
- `cardId`: Foreign key linking expenses to their credit card (stored as an account)
- `isRecurrent`: Boolean flag for recurring bills (subscriptions, rent, etc.)
- `recurrenceId`: Links child instances to their parent recurrence definition
- `month`, `year`: Explicit month/year fields for when the bill is due (nullable for cards)

**Performance Optimizations:**
- WAL mode enabled via `PRAGMA journal_mode = WAL`
- Indexed fields: `typeId`, `month+year`, `cardId`, `purchaseUuid`, `isRecurrent`
- Batch operations for series movements using `db.batch()`
- Cache size set to 10MB via `PRAGMA cache_size = -10000`

**Database Access Pattern:**
```dart
final db = await DatabaseHelper.instance.database;
```

### Platform-Specific Initialization

Desktop platforms (Windows/Linux/macOS) require `sqflite_common_ffi` initialization in `main.dart`:
```dart
if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
```

### Services Layer

**PrefsService** (`lib/services/prefs_service.dart`):
- Wraps `SharedPreferences` for user settings
- Exposes reactive notifiers: `themeNotifier` (ThemeMode), `regionNotifier`, `cityNotifier`
- Persists date range selections for dashboard filtering
- Theme preference stored under key `isDark`

**HolidayService** (`lib/services/holiday_service.dart`):
- Defines Brazilian banking holidays (national + municipal for Vale do Paraíba and Litoral Norte)
- `adjustDateToBusinessDay(date, city)` shifts due dates from weekends/holidays to next business day
- Returns adjusted date plus warning message for UI display
- Maintains region → cities mapping in `HolidayService.regions`

### Credit Card & Installment Model

Credit cards are stored as `Account` records with `cardBrand != null`. Card expenses reference the card via `cardId`.

**Installment Series:**
- Purchases are linked via `purchaseUuid` (UUID v4 generated at creation)
- Description pattern: "Base Description (1/N)", "(2/N)", etc.
- Batch operations use `purchaseUuid` for moving/deleting entire series
- `DatabaseHelper.moveInstallmentSeriesByUuid()` and `deleteInstallmentSeriesByUuid()` handle series operations

**Recurring Expenses (Subscriptions):**
- Use `isRecurrent = true` and `recurrenceId` to link instances
- Parent record has `recurrenceId = null`, children point to parent's `id`
- `deleteSubscriptionSeries()` removes parent and all children

## Code Conventions

**Naming:**
- Files: `snake_case` (e.g., `account_form_screen.dart`)
- Classes: `PascalCase` (e.g., `DatabaseHelper`)
- Variables/Functions: `camelCase` (e.g., `readAllCards()`)

**Models:**
- Implement `toMap()` and `fromMap()` for serialization
- Provide `copyWith()` for immutable updates
- Use getters for derived properties (e.g., `isCreditCard`, `isOverdue`)
- Booleans stored as INTEGER (0/1) in SQLite

**State Management:**
- Prefer `ValueNotifier` for simple reactive state
- Use `StatefulWidget` with `setState()` for screen-level state
- Avoid introducing heavy frameworks (Provider, Riverpod, Bloc) unless absolutely necessary

## Database Schema Management

**Current Version:** 1 (see `_initDB` in `lib/database/db_helper.dart`)

**Schema Changes:**
- Increment `version` parameter in `_initDB()`
- Implement `onUpgrade` callback to handle migrations
- Test on all platforms (mobile + desktop) as they use different SQLite implementations
- Be cautious with ALTER TABLE - consider recreate-and-copy strategy for complex changes

## Important Patterns and Gotchas

**Date Handling:**
- App uses Brazilian locale: `initializeDateFormatting('pt_BR', null)` in `main.dart`
- Always consider holiday adjustments when setting due dates
- Use `HolidayService.adjustDateToBusinessDay()` for vencimentos

**Batch Operations:**
- For moving/deleting multiple accounts, use `db.batch()` to minimize DB round-trips
- See `moveInstallmentSeriesByUuid()` and `moveInstallmentSeries()` as examples

**Desktop Database Conflicts:**
- WAL mode is enabled - avoid opening multiple database factories
- Follow `sqflite_common_ffi` initialization pattern strictly

**Holiday Regions:**
- Cities are defined in `HolidayService.regions` - update carefully to maintain consistency
- User preferences reference these city names directly

**Account Types:**
- App ships with 6 default types (see `_createDB` in db_helper.dart)
- "Cartões de Crédito" type used for credit card entries
- Foreign key cascade deletes types → accounts

## Localization

- Locale: Brazilian Portuguese (`pt_BR`)
- Currency formatting: Uses `brasil_fields` package
- Date formatting: Uses `intl` package with pt_BR locale
- All UI strings are currently hardcoded in Portuguese

## Key Files Reference

- `lib/main.dart`: App entry point, theme configuration, platform initialization
- `lib/database/db_helper.dart`: All database operations, schema definition, CRUD methods
- `lib/models/account.dart`: Core data model with 27 fields supporting both bills and cards
- `lib/services/prefs_service.dart`: User preferences with reactive notifiers
- `lib/services/holiday_service.dart`: Business day calculation and holiday definitions
- `lib/screens/dashboard_screen.dart`: Main screen, entry point after app launch

## Quick Reference Examples

**Access database:**
```dart
final db = await DatabaseHelper.instance.database;
```

**Check if account type exists:**
```dart
await DatabaseHelper.instance.checkAccountTypeExists('Nome do Tipo');
```

**Adjust date to business day:**
```dart
final result = HolidayService.adjustDateToBusinessDay(DateTime.now(), 'São José dos Campos');
DateTime adjustedDate = result.date;
String? warningMessage = result.warning;
```

**Read all credit cards:**
```dart
final cards = await DatabaseHelper.instance.readAllCards();
```

**Move installment series:**
```dart
await DatabaseHelper.instance.moveInstallmentSeriesByUuid(purchaseUuid, monthOffset);
```

**Listen to theme changes:**
```dart
PrefsService.themeNotifier.addListener(() {
  // React to theme changes
});
```
