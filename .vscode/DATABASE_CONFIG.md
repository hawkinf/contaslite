# 🗄️ Configuração de Banco de Dados Dual (SQLite + PostgreSQL)

## Visão Geral

O aplicativo agora suporta dois bancos de dados:

- **SQLite** (Offline): Banco local para quando não há internet
- **PostgreSQL** (Online): Banco remoto para sincronização online

O sistema **troca automaticamente** entre os dois baseado na conectividade.

## 📋 Arquitetura

```
DatabaseManager (Gerenciador Central)
├── SQLiteImpl (Offline)
│   └── Local: .dart_tool/sqflite_common_ffi/databases/finance_v62.db
├── PostgreSQLImpl (Online)
│   └── Remoto: seu-servidor.com:5432/database
└── Conectividade
    └── Monitora mudanças de internet
        ├── Sem internet → SQLite
        └── Com internet → PostgreSQL (se disponível)
```

## ⚙️ Configuração

### 1. Adicionar ao main.dart

```dart
import 'package:finance_app/database/database_manager.dart';
import 'package:finance_app/database/postgresql_impl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar PostgreSQL
  final postgresConfig = PostgreSQLConfig(
    host: 'seu-servidor.com',
    port: 5432,
    database: 'finance_db',
    username: 'usuario',
    password: 'senha',
  );

  // Inicializar DatabaseManager
  await DatabaseManager().initialize(postgresConfig: postgresConfig);

  // ... resto do código
}
```

### 2. Variáveis de Ambiente (Recomendado)

Crie um arquivo `.env`:

```
POSTGRES_HOST=seu-servidor.com
POSTGRES_PORT=5432
POSTGRES_DB=finance_db
POSTGRES_USER=usuario
POSTGRES_PASS=senha
```

Depois use:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

final postgresConfig = PostgreSQLConfig(
  host: dotenv.env['POSTGRES_HOST']!,
  port: int.parse(dotenv.env['POSTGRES_PORT']!),
  database: dotenv.env['POSTGRES_DB']!,
  username: dotenv.env['POSTGRES_USER']!,
  password: dotenv.env['POSTGRES_PASS']!,
);
```

## 🔄 Como Funciona

### Fluxo Automático

1. **App inicia** → Inicializa SQLite e PostgreSQL
2. **Verifica internet** → Via `connectivity_plus`
3. **Se tem internet**
   - Tenta conectar ao PostgreSQL
   - Se sucesso → Usa PostgreSQL
   - Se falha → Volta para SQLite
4. **Se sem internet** → Usa SQLite
5. **Monitora constantemente** → Muda de banco se conectividade mudar

### Troca de Banco em Tempo Real

```dart
// Obter referência ao DatabaseManager
final dbManager = DatabaseManager();

// Ouvir mudanças de tipo de banco
dbManager.databaseTypeNotifier.addListener(() {
  final tipo = dbManager.currentDatabaseType;
  print('Banco atual: $tipo');
  // sqlite ou postgresql
});

// Ouvir mudanças de conectividade
dbManager.isOnlineNotifier.addListener(() {
  if (dbManager.isOnline) {
    print('Online - usando PostgreSQL');
  } else {
    print('Offline - usando SQLite');
  }
});
```

## 💾 Usar o Banco de Dados

A interface é idêntica para ambos os bancos:

```dart
final dbManager = DatabaseManager();
final db = dbManager.database;

// SELECT
final contas = await db.query(
  'SELECT * FROM accounts WHERE month = ?',
  args: [1],
);

// INSERT
final id = await db.insert(
  'accounts',
  values: {
    'description': 'Aluguel',
    'value': 1500.00,
    'dueDay': 15,
  },
);

// UPDATE
await db.update(
  'accounts',
  values: {'value': 1600.00},
  where: 'id = ?',
  whereArgs: [1],
);

// DELETE
await db.delete(
  'accounts',
  where: 'id = ?',
  whereArgs: [1],
);

// TRANSAÇÃO
await db.transaction(() async {
  await db.update(...);
  await db.insert(...);
});
```

## 🔄 Sincronização de Dados

### Sincronizar Manualmente

```dart
final dbManager = DatabaseManager();

// Sincronizar dados entre SQLite e PostgreSQL
await dbManager.syncData();
```

### Implementar Lógica de Sincronização

No arquivo `database_manager.dart`, implemente o método `syncData()`:

```dart
Future<void> syncData() async {
  if (!isOnline) return;

  // 1. Buscar dados modificados no SQLite
  final modified = await _sqlite.query(
    'SELECT * FROM accounts WHERE syncedAt IS NULL'
  );

  // 2. Enviar para PostgreSQL
  for (final row in modified) {
    await _postgresql.insert('accounts', values: row);
  }

  // 3. Buscar dados novos do PostgreSQL
  final newData = await _postgresql.query(
    'SELECT * FROM accounts WHERE lastModified > ?',
    args: [lastSyncTime],
  );

  // 4. Atualizar SQLite
  for (final row in newData) {
    await _sqlite.insert('accounts', values: row);
  }
}
```

## 📊 Monitorar Status

```dart
final dbManager = DatabaseManager();

// Status atual
print('Tipo: ${dbManager.currentDatabaseType}');
print('Online: ${dbManager.isOnline}');
print('Conectado SQLite: ${await dbManager._sqlite.isConnected()}');
print('Conectado PostgreSQL: ${await dbManager._postgresql.isConnected()}');

// Reconectar ao PostgreSQL
await dbManager.reconnectPostgres();
```

## 🔐 Segurança

### Credenciais PostgreSQL

**NUNCA** coloque credenciais hardcoded no código:

❌ Errado:
```dart
final config = PostgreSQLConfig(
  host: 'server.com',
  username: 'admin',
  password: 'senha123', // NÃO!
);
```

✅ Correto:
```dart
// Use variáveis de ambiente
final config = PostgreSQLConfig(
  host: dotenv.env['DB_HOST']!,
  username: dotenv.env['DB_USER']!,
  password: dotenv.env['DB_PASS']!,
);

// Ou use Secure Storage
final secureStorage = FlutterSecureStorage();
final password = await secureStorage.read(key: 'db_password');
```

## 🚨 Tratamento de Erros

### Quando PostgreSQL cai

O aplicativo **automaticamente** volta para SQLite:

```dart
try {
  // Operação com PostgreSQL
  final dados = await db.query('SELECT * FROM accounts');
} catch (e) {
  // Se erro, DatabaseManager muda para SQLite automaticamente
  print('Erro ao acessar PostgreSQL, usando SQLite');
}
```

### Reconectar Manualmente

```dart
// Se PostgreSQL cair, reconecte manualmente
await DatabaseManager().reconnectPostgres();
```

## 📈 Performance

### SQLite (Offline)
- ⚡ Muito rápido
- 💾 Usa espaço local
- ✅ Sem latência de rede

### PostgreSQL (Online)
- 🌐 Acesso centralizado
- 🔄 Sincronização automática
- ⏱️ Latência de rede (~100-500ms)

## 🔧 Troubleshooting

### PostgreSQL não conecta

```dart
// Verificar conectividade de rede
final result = await Connectivity().checkConnectivity();
print('Conectividade: $result');

// Testar endpoint
final response = await http.get(
  Uri.parse('http://seu-servidor.com:8080/health')
);
print('Status: ${response.statusCode}');
```

### Sincronização não funciona

1. Verificar se ambos os bancos existem
2. Verificar estrutura de tabelas
3. Verificar logs de erro
4. Executar `syncData()` manualmente

## 📝 Próximas Etapas

1. Implementar API REST no servidor PostgreSQL
2. Implementar lógica completa de sincronização
3. Adicionar versionamento de dados
4. Implementar conflito resolution
5. Adicionar criptografia de dados sensíveis
