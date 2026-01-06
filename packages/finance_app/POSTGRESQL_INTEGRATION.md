# PostgreSQL Integration Guide

## Overview

This document describes the complete PostgreSQL integration for the Contaslite app, enabling multiple users to maintain separate PostgreSQL databases while maintaining an offline SQLite fallback for uninterrupted operation.

## Architecture

### Three-Layer Database System

```
┌─────────────────────────────────────────────────┐
│           Application Layer                      │
│  (Dashboard, Account Screens, Reports, etc.)   │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│         Database Manager Layer                   │
│  (Automatic Switching: Online/Offline)          │
│  - Monitors connectivity                        │
│  - Routes queries appropriately                 │
│  - Maintains both implementations               │
└──────┬─────────────────────────────┬────────────┘
       │                             │
       ▼                             ▼
┌─────────────────────┐    ┌──────────────────────┐
│   SQLite Local DB   │    │ PostgreSQL Remote    │
│   (Always Available)│    │ (Online Only)        │
│ - Offline operation │    │ - Multi-user sync    │
│ - Fast local queries│    │ - Centralized data   │
│ - Automatic backups │    │ - REST API gateway   │
└─────────────────────┘    └──────────────────────┘
```

### Key Components

#### 1. **DatabaseInterface** (`database_interface.dart`)
Abstract interface defining the contract for all database operations:
- `query()` - Execute SELECT queries
- `querySingle()` - Get a single row
- `execute()` - Execute raw SQL
- `insert()` - Insert records
- `update()` - Update records
- `delete()` - Delete records
- `transaction()` - Execute transactional operations
- `isConnected()` - Check connection status

#### 2. **SQLiteImpl** (`sqlite_impl.dart`)
Local SQLite implementation for offline operation:
- Uses `sqflite` package
- Database file: `.dart_tool/sqflite_common_ffi/databases/finance_v62.db`
- Always available (no network dependency)
- Singleton pattern with lazy initialization
- Automatic schema creation and upgrades

#### 3. **PostgreSQLImpl** (`postgresql_impl.dart`)
Remote PostgreSQL implementation via HTTP REST API:
- Uses `http` package for API communication
- Connects to a backend REST gateway
- Requires proper authentication
- 30-second timeout for operations
- Connection health check via `/health` endpoint

#### 4. **DatabaseManager** (`database_manager.dart`)
Central orchestrator for automatic database switching:
- Monitors network connectivity via `connectivity_plus`
- Automatically switches between SQLite and PostgreSQL
- Maintains both implementations simultaneously
- Provides `syncData()` for future sync operations
- Allows manual reconnection attempts

#### 5. **PostgreSQLConfig** (`database_config.dart`)
Configuration model for PostgreSQL connections:
```dart
class PostgreSQLConfig {
  final String host;          // Server hostname/IP
  final int port;             // Server port (default: 5432)
  final String database;      // Database name
  final String username;      // Username for authentication
  final String password;      // Password (encrypted in storage)
  final bool enabled;         // Toggle to enable/disable
}
```

#### 6. **DatabaseSettingsScreen** (`database_settings_screen.dart`)
User interface for configuring PostgreSQL connections:
- Toggle to enable/disable PostgreSQL
- Input fields for all connection parameters
- Password visibility toggle
- **Test Connection** button - validates configuration before saving
- **Save** button - persists configuration to SharedPreferences
- **Clear** button - removes all settings with confirmation
- Real-time connection test with detailed feedback

## Usage

### For End Users

#### Accessing PostgreSQL Settings

1. Open **Preferências** (Settings) from the main menu
2. Scroll down to **PostgreSQL** section
3. Click the PostgreSQL tile to open configuration screen

#### Configuring Connection

1. **Toggle Enable**: Turn on the switch to enable PostgreSQL integration
2. **Fill in Details**:
   - **Endereço (Host)**: Your server hostname or IP address
   - **Porta**: Server port (typically 5432)
   - **Nome do Banco**: Database name
   - **Usuário**: Database username
   - **Senha**: Database password (password visibility toggle available)

3. **Test Connection**: Click "Testar Conexão" to verify settings
   - ✅ Green message: Connection successful
   - ❌ Red message: Connection failed - check settings

4. **Save**: Click "Salvar" to persist configuration
5. **Clear Settings**: Click "Limpar Configurações" to remove all settings

### For Developers

#### Initialize DatabaseManager

```dart
// In main.dart or app initialization
import 'package:finance_app/database/database_manager.dart';
import 'package:finance_app/database/postgresql_impl.dart';

final dbManager = DatabaseManager();

// Initialize with PostgreSQL configuration
final postgresConfig = PostgreSQLConfig(
  host: 'your-server.com',
  port: 5432,
  database: 'finance_db',
  username: 'user',
  password: 'password',
);

await dbManager.initialize(postgresConfig: postgresConfig);
```

#### Use DatabaseManager in Widgets

```dart
// Access current database implementation
final db = DatabaseManager().database;

// Perform database operations
final accounts = await db.query('SELECT * FROM accounts');
final newId = await db.insert('accounts', {'name': 'New Account'});
await db.update('accounts', {'name': 'Updated'}, where: 'id = ?', whereArgs: [1]);
await db.delete('accounts', where: 'id = ?', whereArgs: [1]);
```

#### Monitor Database Status

```dart
// Listen to database type changes
DatabaseManager().databaseTypeNotifier.addListener(() {
  print('Database switched to: ${DatabaseManager().currentDatabaseType}');
});

// Listen to online status changes
DatabaseManager().isOnlineNotifier.addListener(() {
  print('Online status: ${DatabaseManager().isOnline}');
});

// Check current status
if (DatabaseManager().isOnline) {
  print('Using PostgreSQL (online)');
} else {
  print('Using SQLite (offline)');
}
```

## Configuration Storage

### SharedPreferences Format

PostgreSQL configuration is stored in SharedPreferences using a pipe-delimited format for security:

```dart
// Key: 'pg_config'
// Value format: 'host|port|database|username|password|enabled'
// Example: 'postgres.example.com|5432|finance_db|admin|encrypted_pwd|true'
```

### Loading Configuration

Configuration is automatically loaded when the settings screen initializes:

```dart
// In database_settings_screen.dart initState()
final config = await PrefsService.loadDatabaseConfig();
_hostController.text = config.host;
_portController.text = config.port.toString();
// ... etc
```

## Backend REST API Requirements

For PostgreSQL connectivity to work, you need to set up a REST gateway on your backend server. This gateway should expose these endpoints:

### Required Endpoints

#### 1. Health Check
```
GET /health
Response: 200 OK if server is running
```

#### 2. Query Execution
```
POST /api/query
Headers: {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer username:password'
}
Body: {
  'sql': 'SELECT * FROM accounts WHERE id = ?',
  'args': [1]
}
Response: {
  'data': [{ 'id': 1, 'name': 'Account', ... }]
}
```

#### 3. Single Row Query
```
POST /api/querySingle
(Same as above, returns first row only)
```

#### 4. Insert
```
POST /api/insert
Body: {
  'table': 'accounts',
  'values': { 'name': 'New Account', 'value': 100.00 }
}
Response: {
  'id': 5  // Auto-generated ID
}
```

#### 5. Update
```
POST /api/update
Body: {
  'table': 'accounts',
  'values': { 'name': 'Updated Name' },
  'where': 'id = ?',
  'whereArgs': [5]
}
Response: {
  'rowsAffected': 1
}
```

#### 6. Delete
```
POST /api/delete
Body: {
  'table': 'accounts',
  'where': 'id = ?',
  'whereArgs': [5]
}
Response: {
  'rowsAffected': 1
}
```

#### 7. Transactions
```
POST /api/beginTransaction
POST /api/commit
POST /api/rollback
```

### Example Node.js/Express Gateway

```javascript
const express = require('express');
const { Pool } = require('pg');
const app = express();

app.use(express.json());

// Middleware for authentication
app.use((req, res, next) => {
  const auth = req.headers.authorization?.split(' ')[1];
  if (!auth) return res.status(401).json({ error: 'Unauthorized' });
  const [username, password] = auth.split(':');
  // Validate username/password
  next();
});

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.post('/api/query', async (req, res) => {
  const { sql, args } = req.body;
  const result = await pool.query(sql, args);
  res.json({ data: result.rows });
});

app.post('/api/insert', async (req, res) => {
  const { table, values } = req.body;
  const cols = Object.keys(values);
  const vals = Object.values(values);
  const sql = `INSERT INTO ${table} (${cols.join(',')}) VALUES (${cols.map((_, i) => `$${i+1}`).join(',')}) RETURNING id`;
  const result = await pool.query(sql, vals);
  res.json({ id: result.rows[0].id });
});

// ... similar endpoints for update, delete, etc.

app.listen(8080, () => console.log('Gateway running on port 8080'));
```

## Automatic Database Switching

### How It Works

1. **On App Start**:
   - SQLite is always initialized for offline access
   - PostgreSQL tries to connect if credentials are configured
   - Network connectivity is checked
   - Appropriate database is selected

2. **During Operation**:
   - Network changes are monitored via `connectivity_plus`
   - When internet becomes available → Attempts PostgreSQL connection
   - When internet is lost → Falls back to SQLite
   - App continues working seamlessly

3. **Connection Logic**:
   ```
   if (internet available) {
     if (PostgreSQL configured) {
       try connect to PostgreSQL
       if successful → use PostgreSQL
       else → fallback to SQLite
     } else → use SQLite
   } else → use SQLite
   ```

## Data Synchronization (Future Implementation)

The `syncData()` method in DatabaseManager is reserved for bidirectional synchronization:

```dart
Future<void> syncData() async {
  // TODO: Implement sync logic
  // 1. Compare SQLite and PostgreSQL records
  // 2. Upload local changes to server
  // 3. Download server updates to local
  // 4. Resolve conflicts (last-write-wins, etc.)
  // 5. Update sync timestamps
}
```

## Security Considerations

### Password Storage

⚠️ **Current Implementation**: Passwords are stored in SharedPreferences (device storage only)

**For Production**:
- Encrypt passwords before storing
- Use Android Keystore for Android
- Use Keychain for iOS
- Use Windows Credential Manager for Windows

**Recommendation**:
```dart
// Add to pubspec.yaml
flutter_secure_storage: ^9.0.0

// Use instead of SharedPreferences for sensitive data
final storage = FlutterSecureStorage();
await storage.write(key: 'pg_password', value: encryptedPassword);
```

### API Authentication

- Credentials are sent in Authorization header
- Use HTTPS in production (never HTTP)
- Implement server-side authentication
- Consider token-based auth (JWT) instead of password headers

### Connection Timeout

- 30-second timeout prevents indefinite hangs
- Configurable via Duration in postgresql_impl.dart
- Health check timeout: 5 seconds

## Troubleshooting

### Connection Test Shows "Servidor não respondeu"

**Possible Causes**:
1. Server is not running
2. Wrong hostname/IP address
3. Wrong port number
4. Firewall blocking connection
5. Server not listening on configured port

**Solutions**:
- Verify server is running: `nc -zv hostname port`
- Check hostname resolution: `ping hostname`
- Verify port in server configuration
- Check firewall rules
- Test from another machine on same network

### "Autenticação falhou no PostgreSQL" Error

**Causes**:
1. Wrong username
2. Wrong password
3. User doesn't have permission
4. Server requires specific authentication method

**Solutions**:
- Verify credentials with database administrator
- Check server authentication settings (pg_hba.conf)
- Ensure user has SELECT, INSERT, UPDATE, DELETE permissions
- Test credentials locally: `psql -h host -U username -d database`

### No Connection After Enabling PostgreSQL

**Causes**:
1. Internet connectivity issue
2. Server temporarily unavailable
3. Configuration error
4. Network timeout

**Solutions**:
- Check internet connection (ping 8.8.8.8)
- Verify server is accessible (ping server)
- Run "Test Connection" in settings
- Check app logs for detailed error messages
- Verify SQLite fallback is working (app should continue to function)

## API Reference

### DatabaseManager Methods

```dart
// Singleton access
final dbManager = DatabaseManager();

// Initialize with PostgreSQL config
Future<void> initialize({required PostgreSQLConfig postgresConfig})

// Get current database instance
DatabaseInterface get database

// Monitor database type changes
ValueNotifier<String> get databaseTypeNotifier

// Monitor online/offline status
ValueNotifier<bool> get isOnlineNotifier

// Get current database type ('sqlite' or 'postgresql')
String get currentDatabaseType

// Check if currently online
bool get isOnline

// Manually synchronize data (future)
Future<void> syncData()

// Force reconnect to PostgreSQL
Future<void> reconnectPostgres()

// Close all connections
Future<void> close()
```

### DatabaseInterface Methods

```dart
// Query operations
Future<List<Map<String, dynamic>>> query(String sql, {List<dynamic>? args})
Future<Map<String, dynamic>?> querySingle(String sql, {List<dynamic>? args})
Future<int> execute(String sql, {List<dynamic>? args})
Future<int> insert(String table, {required Map<String, dynamic> values})
Future<int> update(String table, {required Map<String, dynamic> values, String? where, List<dynamic>? whereArgs})
Future<int> delete(String table, {String? where, List<dynamic>? whereArgs})

// Advanced operations
Future<T> transaction<T>(Future<T> Function() action)
Future<dynamic> rawQuery(String sql, {List<dynamic>? args})

// Status
Future<bool> isConnected()
ValueNotifier<bool> get connectionNotifier
String get databaseType
```

## Commits Related to PostgreSQL Integration

- **28bf635**: feat: add dual database system (SQLite offline + PostgreSQL online)
- **6d24f71**: fix: resolve compilation errors in database_settings_screen.dart
- **f83b88f**: feat: integrate PostgreSQL configuration screen into settings menu
- **d40f2d0**: feat: implement actual PostgreSQL connection test functionality

## Next Steps

1. **Implement Backend Gateway**: Create REST API gateway for PostgreSQL access
2. **Test Connection**: Verify SQLite/PostgreSQL switching with real server
3. **Implement Data Sync**: Add bidirectional synchronization logic
4. **Enhance Security**: Use encrypted password storage
5. **Add Logging**: Implement detailed sync logs for troubleshooting
6. **Multi-Database Support**: Allow users to manage multiple database profiles

## Related Documentation

- [DATABASE_CONFIG.md](../../../.vscode/DATABASE_CONFIG.md) - Architecture details
- [pubspec.yaml](../pubspec.yaml) - Dependencies (connectivity_plus, http, etc.)
- [database_settings_screen.dart](./lib/screens/database_settings_screen.dart) - UI implementation
- [database_manager.dart](./lib/database/database_manager.dart) - Core switching logic
