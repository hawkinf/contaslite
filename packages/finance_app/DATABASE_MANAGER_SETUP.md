# DatabaseManager Setup Guide

## Overview

The `DatabaseManager` is a singleton that automatically manages switching between SQLite (offline) and PostgreSQL (online) based on network connectivity. This guide explains how to integrate it into your app.

## Current State

Currently, the app works without DatabaseManager integration. All database operations use `DbHelper` which only supports SQLite.

## Optional Integration Steps

To enable PostgreSQL support alongside SQLite, follow these steps:

### Step 1: Import DatabaseManager in main.dart

```dart
import 'package:finance_app/database/database_manager.dart';
import 'package:finance_app/database/postgresql_impl.dart';
```

### Step 2: Initialize in main() function

Add to your `main()` function after other initializations:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... existing initializations ...

  // Initialize DatabaseManager with saved PostgreSQL config
  try {
    final dbManager = DatabaseManager();
    final dbConfig = await PrefsService.loadDatabaseConfig();

    final postgresConfig = PostgreSQLConfig(
      host: dbConfig.host,
      port: dbConfig.port,
      database: dbConfig.database,
      username: dbConfig.username,
      password: dbConfig.password,
    );

    await dbManager.initialize(postgresConfig: postgresConfig);

    debugPrint('✅ DatabaseManager initialized successfully');
  } catch (e) {
    debugPrint('⚠️ DatabaseManager initialization failed: $e');
    debugPrint('⚠️ Falling back to SQLite only');
  }

  // ... rest of main ...
}
```

### Step 3: Update Database Access Points

Once DatabaseManager is initialized, you have two options:

**Option A: Hybrid Mode** (Recommended for gradual migration)
Keep using `DbHelper` for all existing code, add new code using `DatabaseManager`.

**Option B: Full Integration** (Requires code changes)
Replace all `DbHelper` calls with `DatabaseManager().database` calls.

#### Example: Option A (Hybrid Mode)

```dart
// Keep using DbHelper for backwards compatibility
final accounts = await DbHelper.getAccounts();

// New code uses DatabaseManager
final db = DatabaseManager().database;
final users = await db.query('SELECT * FROM users');
```

#### Example: Option B (Full Integration)

Replace:
```dart
// Old way (SQLite only)
final accounts = await DbHelper.getAccounts();
```

With:
```dart
// New way (SQLite or PostgreSQL)
final db = DatabaseManager().database;
final results = await db.query(
  'SELECT * FROM accounts WHERE id = ?',
  args: [accountId],
);
final accounts = results.cast<Map<String, dynamic>>();
```

### Step 4: Monitor Database Status (Optional)

Add listeners to track when the database switches:

```dart
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Listen to database type changes
    DatabaseManager().databaseTypeNotifier.addListener(_onDatabaseTypeChanged);

    // Listen to online status changes
    DatabaseManager().isOnlineNotifier.addListener(_onOnlineStatusChanged);
  }

  void _onDatabaseTypeChanged() {
    final type = DatabaseManager().currentDatabaseType;
    debugPrint('🔄 Database switched to: $type');

    // Refresh UI or sync data if needed
    setState(() {});
  }

  void _onOnlineStatusChanged() {
    final isOnline = DatabaseManager().isOnline;
    debugPrint('🔌 Online status: $isOnline');

    if (isOnline) {
      // Sync data from SQLite to PostgreSQL
      // DatabaseManager().syncData();
    }
  }

  @override
  void dispose() {
    DatabaseManager().databaseTypeNotifier.removeListener(_onDatabaseTypeChanged);
    DatabaseManager().isOnlineNotifier.removeListener(_onOnlineStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ... your app config ...
    );
  }
}
```

### Step 5: Shutdown on App Close

Add cleanup to your app shutdown:

```dart
// In your main app widget or when app closes
Future<void> _closeApp() async {
  await DatabaseManager().close();
  // Close other resources
  exit(0);
}
```

## Architecture Decision Tree

Choose your integration strategy based on your needs:

```
┌─ Do you need PostgreSQL support? ──────────────────┐
│                                                    │
└─ YES ──────────────────────────────────────────────┘
    │
    ├─ Can you modify all database code?
    │   └─ YES → Full Integration (Option B)
    │            - Replaces all DbHelper calls
    │            - Cleaner architecture
    │            - More changes required
    │
    └─ NO → Hybrid Mode (Option A)
             - Keep DbHelper as-is
             - Add DatabaseManager for new features
             - Gradual migration path
             - Less risky

┌─ No PostgreSQL support needed? ────────────────────┐
│                                                    │
└─ Keep using DbHelper as-is ───────────────────────┘
    - No changes required
    - App works perfectly with SQLite
    - Add PostgreSQL anytime in future
```

## Testing Integration

### Manual Testing Checklist

- [ ] App starts without errors
- [ ] Settings > PostgreSQL shows configuration screen
- [ ] Can enable/disable PostgreSQL toggle
- [ ] Test Connection button works
- [ ] Configuration saves and loads
- [ ] When online: Should show database type in logs
- [ ] When offline: Should fall back to SQLite
- [ ] App functionality works normally
- [ ] No data loss when switching databases

### Debug Logging

Monitor database switching in debug output:

```
// Expected logs during startup:
✅ DatabaseManager initialized successfully
📱 Inicializando SQLite em: /path/to/finance_v62.db
✅ SQLite inicializado com sucesso
🌐 Inicializando PostgreSQL em: your_host
✅ PostgreSQL conectado com sucesso
📊 Banco atual: postgresql

// When going offline:
🔌 Mudança de conectividade: ConnectivityResult.none
📱 Alternando para SQLite (offline)

// When going online:
🔌 Mudança de conectividade: ConnectivityResult.wifi
🌐 Alternando para PostgreSQL (online)
```

## Common Issues

### Issue 1: "DatabaseManager.initialize() called multiple times"

**Solution**: DatabaseManager is a singleton, call it only once:

```dart
// ✅ Correct - called once in main()
void main() async {
  await DatabaseManager().initialize(postgresConfig: config);
  // ...
}

// ❌ Wrong - don't call in other places
class MyWidget extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    // DON'T call initialize here!
    // DatabaseManager().initialize(...); // ❌
  }
}
```

### Issue 2: "PostgreSQL not working, always uses SQLite"

**Checklist**:
1. Is PostgreSQL enabled in settings? (Check toggle)
2. Did test connection pass?
3. Is internet available? (Check WiFi/Mobile)
4. Is backend REST API gateway running?
5. Check logs for error messages

### Issue 3: "Test connection works but data doesn't sync"

**Note**: Data synchronization is a future feature. Currently:
- PostgreSQL connection test only validates server availability
- Actual data sync must be implemented separately
- See `syncData()` TODO in `database_manager.dart`

## Migration Path: Step by Step

If you want to gradually migrate from DbHelper to DatabaseManager:

### Phase 1: Add DatabaseManager (No Code Changes)
- Initialize DatabaseManager in main()
- Settings screen allows users to configure PostgreSQL
- App continues using DbHelper (SQLite only)
- Users can test PostgreSQL connection
- **Duration**: Immediate, low risk

### Phase 2: Hybrid Mode (Selective Integration)
- New features use `DatabaseManager().database`
- Old code still uses `DbHelper`
- Both implementations coexist
- Gradually convert screens one-by-one
- **Duration**: 1-2 weeks

### Phase 3: Full Integration (Complete Migration)
- All database calls use `DatabaseManager().database`
- Remove `DbHelper` dependency
- Clean, unified architecture
- Full PostgreSQL support
- **Duration**: 2-4 weeks

### Phase 4: Data Synchronization (Future)
- Implement bidirectional sync
- Handle conflicts
- Encryption
- Offline queue management
- **Duration**: 4+ weeks

## Technical Details

### DatabaseManager Lifecycle

```
main() called
    ↓
DatabaseManager().initialize(postgresConfig)
    ├─ SQLite.initialize() [always]
    ├─ PostgreSQL.initialize() [if config exists]
    ├─ Check connectivity
    ├─ Select appropriate database
    └─ Start monitoring connectivity changes

App running
    ├─ DatabaseManager().database  ← use this
    └─ Automatic switching on connectivity changes

App closing
    ↓
DatabaseManager().close()
    ├─ SQLite.close()
    └─ PostgreSQL.close()
```

### Database Selection Algorithm

```dart
if (PostgreSQL configured) {
  if (Internet available) {
    if (PostgreSQL connects) {
      Use PostgreSQL ✅
    } else {
      Use SQLite (PostgreSQL unavailable)
    }
  } else {
    Use SQLite (offline)
  }
} else {
  Use SQLite (PostgreSQL not configured)
}
```

## Performance Considerations

### SQLite (Local)
- ✅ Extremely fast (no network latency)
- ✅ Always available (no connectivity required)
- ✅ ~0ms latency
- ❌ Single device only

### PostgreSQL (Remote)
- ✅ Centralized data (multi-user)
- ✅ Server-side processing
- ✅ Better for large datasets
- ❌ Network latency (typically 50-500ms)
- ❌ Requires internet

### Recommendation

For **most operations**, the network latency of PostgreSQL is negligible. User experience difference:
- SQLite: 10ms
- PostgreSQL: 100ms
- Difference: Imperceptible to users

## Next Steps

1. **Understand current code**: Review how DbHelper is used
2. **Choose strategy**: Decide on Option A (Hybrid) or Option B (Full)
3. **Test locally**: Set up PostgreSQL locally for testing
4. **Implement**: Follow integration steps above
5. **Deploy**: Test thoroughly before releasing

## References

- [POSTGRESQL_INTEGRATION.md](./POSTGRESQL_INTEGRATION.md) - Complete technical guide
- [POSTGRESQL_QUICKSTART.md](./POSTGRESQL_QUICKSTART.md) - User guide
- [database_manager.dart](./lib/database/database_manager.dart) - Source code
- [database_settings_screen.dart](./lib/screens/database_settings_screen.dart) - UI

## Support

For questions or issues:
1. Check the troubleshooting section above
2. Review logs for error messages
3. See POSTGRESQL_INTEGRATION.md for detailed API docs
4. Verify PostgreSQL server is accessible and running
5. Test connection from the settings screen

---

**Last Updated**: January 6, 2026
**Status**: Ready for Integration
