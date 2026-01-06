# PostgreSQL Quick Start Guide

## 5-Minute Setup

### Step 1: Access PostgreSQL Settings
1. Open the app → **Preferências** (Settings)
2. Scroll to the bottom → Click **PostgreSQL** tile

### Step 2: Enable PostgreSQL
- Toggle the switch to **ON**
- You should see "🟢 Habilitado" (Enabled)

### Step 3: Enter Your Database Details

Fill in these fields with information from your database administrator:

| Field | Example | Notes |
|-------|---------|-------|
| **Endereço (Host)** | `postgres.example.com` | Your database server address |
| **Porta** | `5432` | Usually 5432 (default PostgreSQL port) |
| **Nome do Banco** | `finance_db` | Database name |
| **Usuário** | `admin` | Database username |
| **Senha** | `••••••••** | Database password |

### Step 4: Test Connection
1. Click **"Testar Conexão"** (Test Connection)
2. Wait a few seconds for the test to complete
3. Look for one of these messages:
   - ✅ **Green**: "Conexão com PostgreSQL bem-sucedida!" → Connection successful
   - ❌ **Red**: "Servidor não respondeu..." → Check your settings

### Step 5: Save Configuration
If the test was successful:
- Click **"Salvar"** (Save)
- You'll see a confirmation message

### Done! 🎉
Your app will now:
- Use PostgreSQL when connected to the internet
- Automatically switch to SQLite when offline
- Continue working seamlessly regardless of connection status

---

## Troubleshooting

### ❌ "Servidor não respondeu"

This means the app can't reach your database. Check:

1. **Is the host correct?**
   - Ask your admin for the exact server address
   - Try pinging it: `ping postgres.example.com`

2. **Is the port correct?**
   - Default PostgreSQL port is `5432`
   - Ask your admin if it's different

3. **Is your internet working?**
   - Try accessing a website
   - Check WiFi or mobile data connection

4. **Is the server running?**
   - Ask your database administrator to check server status
   - Server must be accessible from outside your network

5. **Firewall blocking?**
   - Your network may block external database connections
   - Contact your IT department to allow access

### ❌ "Autenticação falhou"

Your username or password is wrong. Check:

1. **Correct username?**
   - Verify spelling (case-sensitive)
   - Ask your admin for the username

2. **Correct password?**
   - Ensure no extra spaces
   - Password is case-sensitive
   - Use "Senha" visibility toggle to verify

3. **Permissions?**
   - Your user account must have database access
   - Contact your admin to verify permissions

### ✅ Test passed, but still not syncing?

If the connection test succeeds but you don't see online features:
- The backend REST API gateway may not be set up yet
- Contact your system administrator
- The app will continue to work offline using SQLite

---

## Getting Your Database Information

### If you have a DBA/Admin:
Ask them for:
- Database server hostname or IP address
- Port number (usually 5432)
- Database name
- Your username
- Your password

### If you're the admin:

**For PostgreSQL already running:**
```bash
# Get connection string
psql -h localhost -U postgres -d your_database

# Inside psql:
\conninfo  # Shows current connection details
```

**For PostgreSQL running on Docker:**
```bash
# Get the container IP
docker inspect <container_id> | grep IPAddress

# Connection info
# Host: <container_ip>
# Port: 5432 (or your mapped port)
# Database: your_db_name
# User: postgres (or your user)
# Password: your_password
```

---

## Multiple Users on Same App

Each person using the app should:
1. Enter their own PostgreSQL credentials
2. Click "Test Connection" to verify
3. Save their settings

The configuration is stored **per device**, so each phone/tablet/computer can have different settings.

---

## What Happens Offline?

When your internet is down:
- The app automatically uses **SQLite** (local database)
- You can continue working normally
- Your work is saved locally
- When internet returns, PostgreSQL is used again

**Note**: Current version stores data locally only. Data sync between SQLite and PostgreSQL is a future enhancement.

---

## Security Notes

⚠️ **Important**:
- Your password is stored on your device
- If someone has physical access to your phone, they could see your password
- Use a strong password for your database account
- Contact your admin if you think your password was compromised

**In future updates**:
- Passwords will be encrypted before storage
- You'll be able to change passwords more easily

---

## Need Help?

Contact your database administrator with:
1. The error message you're seeing
2. Your operating system (Windows, Android, iOS)
3. Screenshot of the error (if possible)
4. What you were trying to do when the error happened

## System Requirements

- **Internet connection** (for online features)
- **PostgreSQL 10+** (on your database server)
- **REST API gateway** (backend component - ask your admin)

---

## Advanced: Manual Connection Test

If the app's test fails but you think it should work, try manually:

**On Windows Command Prompt:**
```cmd
# Install psql if needed (from PostgreSQL installer)
psql -h your_host -p 5432 -U your_username -d your_database
# It will ask for password
```

**On Mac/Linux Terminal:**
```bash
# Install PostgreSQL client
brew install postgresql  # Mac
sudo apt-get install postgresql-client  # Linux

# Test connection
psql -h your_host -p 5432 -U your_username -d your_database
```

If this works, the server is accessible. The app might need a REST API gateway set up.

---

## Still Not Working?

1. ✅ Test connection passes in the app
2. ✅ Configuration is saved
3. ❌ But you're still not seeing online features?

This likely means your backend REST API gateway isn't running. Ask your admin to:
- Set up the REST API gateway for PostgreSQL
- See `POSTGRESQL_INTEGRATION.md` for technical details
- Follow the Node.js/Express example provided

---

**Version**: 1.0
**Last Updated**: January 6, 2026
