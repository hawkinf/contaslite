# Contaslite AI Notes

This project is a Flutter app that combines a calendar/holiday experience with
an embedded finance module from `packages/finance_app`. These notes exist to
help coding assistants quickly understand the main flow, data sources, and
where to make changes.

## Entry point and main flow
- `lib/main.dart` is the single entry point for the app and also contains most
  of the UI for the holiday calendar and tabs.
- The home screen is `HolidayScreen` in `lib/main.dart`. It owns:
  - Tab navigation (`TabController` + `TabBar` + `TabBarView`).
  - Calendar UI (weekly, monthly, annual modes).
  - Holiday data fetching and display.
  - Embedded finance tab: `ContasTab` (wraps the finance app).

## Tabs and navigation
- Tabs are defined in `lib/main.dart` under the `TabBar` and `TabBarView`.
- Keep the number of tabs in sync with `_tabController = TabController(length: N, ...)`.
- The finance module lives under `packages/finance_app` and is shown via
  `ContasTab` in `lib/main.dart`:
  - `ContasTab` loads/initializes the finance database and then renders
    `contas_app.FinanceApp`.

## Holiday data
- Holiday data is fetched from a public API and merged with local city data.
- Key functions are in `lib/main.dart`:
  - `_fetchHolidays(year)` pulls API holidays and merges municipal/banking data.
  - `_getHolidaysForDisplay(year)` fetches current/prev/next year and combines.
- The "next holiday" label in the AppBar is generated from `_holidaysFuture` via
  `_getNextHolidayText`.

## Preferences and state
- Preferences are stored in `packages/finance_app/lib/services/prefs_service.dart`.
- `PrefsService` notifiers are used in `lib/main.dart` to sync:
  - Theme mode.
  - Date range (for the finance module).
  - City/region selection for holidays.

## Database
- Finance database logic is in:
  - `packages/finance_app/lib/database/db_helper.dart`
  - `packages/finance_app/lib/services/database_initialization_service.dart`
- Initialization is triggered from `ContasTab` and `configureContasDatabaseIfNeeded()`.

## Where to change things
- AppBar title/subtitle/next-holiday line: `lib/main.dart` inside `SliverAppBar.large`.
- Tabs (labels, order, screens): `lib/main.dart` inside the `TabBar`/`TabBarView`.
- Finance UI and screens: `packages/finance_app/lib/screens/*`.
- Holiday UI (stats/list/cards): `lib/main.dart` in the "FERIADOS" tab builder.
- Calendar rendering: `lib/main.dart` methods:
  - `_buildCalendarGrid()` for monthly view.
  - `_buildWeeklyCalendar()` for weekly view.
  - `_buildAnnualCalendar()` for yearly view.

## Conventions
- Keep UI text in Portuguese; be mindful of accent/encoding in the file.
- Do not introduce new tabs without updating the `TabController` length.
- Prefer small, targeted changes in `lib/main.dart` since it is already large.

## Common pitfalls
- Missing screen classes cause analyzer errors (e.g., undefined imports).
- Tab count mismatches cause runtime assertion errors.
- Large AppBar titles can overflow on small screens; use `maxLines`/ellipsis.
