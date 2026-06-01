# Swift SDK

Package: `libsql-swift` (GitHub: `https://github.com/tursodatabase/libsql-swift`)

> **Note**: Swift SDK is in Technical Preview.

## Installation

Add via SwiftPM in Xcode or `Package.swift`:

```swift
import PackageDescription
let package = Package(
    // ...
    dependencies: [
        .package(url: "https://github.com/tursodatabase/libsql-swift", from: "0.1.1"),
    ],
    // ...
)
```

Then import in your source:

```swift
import Libsql
```

## Quick Start

```swift
import Libsql

// Local file database
let db = try Database("local.db")
let conn = try db.connect()

// Create table and insert
try conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
try conn.execute("INSERT INTO users VALUES (?)", [1])

// Query
let rows = try conn.query("SELECT * FROM users")
```

## API Reference

### Database

```swift
// Local file
let db = try Database("path/to/db.db")
let conn = try db.connect()

// In-memory
let db = try Database(":memory:")
let conn = try db.connect()

// Embedded replica (local + remote sync)
let db = try Database(
    path: "./local.db",
    url: "TURSO_DATABASE_URL",
    authToken: "TURSO_AUTH_TOKEN"
)
let conn = try db.connect()

// Embedded replica with auto-sync interval (seconds)
let db = try Database(
    path: "./local.db",
    url: "TURSO_DATABASE_URL",
    authToken: "TURSO_AUTH_TOKEN",
    syncInterval: 300
)
let conn = try db.connect()

// Disable read-your-writes (enabled by default)
let db = try Database(
    path: "./local.db",
    url: "TURSO_DATABASE_URL",
    authToken: "TURSO_AUTH_TOKEN",
    readYourWrites: false
)
let conn = try db.connect()
```

### Connection

#### `conn.execute(sql, params)` → Void

Execute INSERT, UPDATE, DELETE, or DDL statements. Throws on error.

```swift
try conn.execute("INSERT INTO users VALUES (?)", [1])
try conn.execute("UPDATE users SET name = ? WHERE id = ?", ["Bob", 1])
try conn.execute("DELETE FROM users WHERE id = ?", [1])
```

#### `conn.query(sql, params)` → Rows

Query data. Throws on error.

```swift
let rows = try conn.query("SELECT * FROM users")
let rows = try conn.query("SELECT * FROM users WHERE id = ?", [1])
```

#### Placeholders

Both positional and named placeholders are supported:

```swift
// Positional
try conn.query("SELECT * FROM users WHERE id = ?", [1])

// Named
try conn.query("SELECT * FROM users WHERE id = :id", [":id": 1])
```

#### `conn.prepare(sql)` → Statement

Prepare a cached statement for repeated execution:

```swift
let stmt = try conn.prepare("SELECT * FROM users WHERE id = ?")
stmt.bind([1])
let rows = stmt.query()
```

## Remote Sync

### Manual sync

```swift
try db.sync()
```

### Sync interval (auto)

Pass `syncInterval` (in seconds) to `Database()` constructor for automatic background sync.

## Notes

- Swift SDK is in **Technical Preview** — APIs may change.
- `readYourWrites` is enabled by default for embedded replicas.
- Named arguments via dictionary syntax: `[":paramName": value]`.
