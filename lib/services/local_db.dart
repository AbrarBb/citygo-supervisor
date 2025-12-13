import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/nfc.dart';
import '../models/ticket.dart';
import '../models/bus.dart';

/// Local SQLite Database for offline storage
class LocalDB {
  static const String _databaseName = 'citygo_supervisor.db';
  static const int _databaseVersion = 4;

  static Database? _database;

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _databaseName);
      
      print('📱 Initializing database at: $path');

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e, stackTrace) {
      print('❌ Database initialization error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Create tables
  Future<void> _onCreate(Database db, int version) async {
    // NFC logs table with offline_id as UNIQUE
    await db.execute('''
      CREATE TABLE nfc_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        offline_id TEXT UNIQUE NOT NULL,
        card_id TEXT NOT NULL,
        bus_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,
        response_data TEXT
      )
    ''');

    // Manual tickets table with offline_id as UNIQUE
    await db.execute('''
      CREATE TABLE manual_tickets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        offline_id TEXT UNIQUE NOT NULL,
        bus_id TEXT NOT NULL,
        passenger_count INTEGER NOT NULL,
        fare REAL NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        notes TEXT,
        seat_number INTEGER,
        drop_stop_id TEXT,
        timestamp INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,
        response_data TEXT
      )
    ''');

    // Cache for assigned bus
    await db.execute('''
      CREATE TABLE bus_cache (
        id INTEGER PRIMARY KEY,
        bus_data TEXT NOT NULL,
        route_data TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('''
      CREATE INDEX idx_nfc_logs_synced ON nfc_logs(synced)
    ''');
    await db.execute('''
      CREATE INDEX idx_nfc_logs_offline_id ON nfc_logs(offline_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_manual_tickets_synced ON manual_tickets(synced)
    ''');
    await db.execute('''
      CREATE INDEX idx_manual_tickets_offline_id ON manual_tickets(offline_id)
    ''');
  }

  /// Upgrade database schema
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add offline_id column if it doesn't exist
      try {
        await db.execute('ALTER TABLE nfc_logs ADD COLUMN offline_id TEXT UNIQUE');
        await db.execute('ALTER TABLE manual_tickets ADD COLUMN offline_id TEXT UNIQUE');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 3) {
      // Add seat_number column if it doesn't exist
      try {
        await db.execute('ALTER TABLE manual_tickets ADD COLUMN seat_number INTEGER');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 4) {
      // Add drop_stop_id column if it doesn't exist
      try {
        await db.execute('ALTER TABLE manual_tickets ADD COLUMN drop_stop_id TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
  }

  /// Save NFC log for offline sync
  Future<int> saveNFCLog(NfcEvent event) async {
    try {
      final db = await database;
      return await db.insert(
        'nfc_logs',
        {
          'offline_id': event.offlineId ?? _generateOfflineId(),
          'card_id': event.cardId,
          'bus_id': event.busId,
          'event_type': event.eventType,
          'latitude': event.latitude,
          'longitude': event.longitude,
          'timestamp': event.timestamp.millisecondsSinceEpoch,
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      print('❌ Error saving NFC log: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Save manual ticket for offline sync
  Future<int> saveManualTicket(ManualTicket ticket) async {
    final db = await database;
    return await db.insert(
      'manual_tickets',
      {
        'offline_id': ticket.offlineId ?? _generateOfflineId(),
        'bus_id': ticket.busId,
        'passenger_count': ticket.passengerCount,
        'fare': ticket.fare,
        'latitude': ticket.latitude,
        'longitude': ticket.longitude,
        'notes': ticket.notes,
        'seat_number': ticket.seatNumber,
        'drop_stop_id': ticket.dropStopId,
        'timestamp': ticket.timestamp.millisecondsSinceEpoch,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all unsynced NFC logs
  Future<List<NfcEvent>> getUnsyncedNFCLogs() async {
    final db = await database;
    final results = await db.query(
      'nfc_logs',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
    return results.map((row) => _nfcLogFromRow(row)).toList();
  }

  /// Get all unsynced manual tickets
  Future<List<ManualTicket>> getUnsyncedManualTickets() async {
    final db = await database;
    final results = await db.query(
      'manual_tickets',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
    return results.map((row) => _manualTicketFromRow(row)).toList();
  }

  /// Mark NFC log as synced
  Future<void> markNFCLogSynced(String offlineId, Map<String, dynamic>? responseData) async {
    final db = await database;
    await db.update(
      'nfc_logs',
      {
        'synced': 1,
        'response_data': responseData != null ? jsonEncode(responseData) : null,
      },
      where: 'offline_id = ?',
      whereArgs: [offlineId],
    );
  }

  /// Mark manual ticket as synced
  Future<void> markManualTicketSynced(String offlineId, Map<String, dynamic>? responseData) async {
    final db = await database;
    await db.update(
      'manual_tickets',
      {
        'synced': 1,
        'response_data': responseData != null ? jsonEncode(responseData) : null,
      },
      where: 'offline_id = ?',
      whereArgs: [offlineId],
    );
  }

  /// Get all offline logs (for sync center)
  Future<List<Map<String, dynamic>>> getAllOfflineLogs() async {
    final db = await database;
    
    final nfcLogs = await db.query(
      'nfc_logs',
      orderBy: 'timestamp DESC',
    );
    
    final manualTickets = await db.query(
      'manual_tickets',
      orderBy: 'timestamp DESC',
    );

    // Combine and format
    final allLogs = <Map<String, dynamic>>[];
    
    for (var log in nfcLogs) {
      allLogs.add({
        ...log,
        'type': 'nfc',
      });
    }
    
    for (var ticket in manualTickets) {
      allLogs.add({
        ...ticket,
        'type': 'manual',
      });
    }

    // Sort by timestamp
    allLogs.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

    return allLogs;
  }

  /// Cache assigned bus data
  Future<void> cacheBusInfo(BusInfo busInfo) async {
    final db = await database;
    await db.insert(
      'bus_cache',
      {
        'id': 1, // Single cache entry
        'bus_data': jsonEncode(busInfo.toJson()),
        'route_data': busInfo.route != null ? jsonEncode(busInfo.route!.toJson()) : null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached bus info
  Future<BusInfo?> getCachedBusInfo() async {
    try {
      final db = await database;
      final results = await db.query(
        'bus_cache',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      
      if (results.isEmpty) return null;
      
      final row = results.first;
      final busDataStr = row['bus_data'] as String?;
      if (busDataStr == null) return null;
      
      final busData = jsonDecode(busDataStr) as Map<String, dynamic>?;
      if (busData == null) return null;
      
      return BusInfo.fromJson(busData);
    } catch (e) {
      print('Error reading cached bus info: $e');
      return null;
    }
  }

  /// Clear all synced logs
  Future<void> clearSyncedLogs() async {
    final db = await database;
    await db.delete(
      'nfc_logs',
      where: 'synced = ?',
      whereArgs: [1],
    );
    await db.delete(
      'manual_tickets',
      where: 'synced = ?',
      whereArgs: [1],
    );
  }

  /// Get count of unsynced items
  Future<int> getUnsyncedCount() async {
    final db = await database;
    final nfcCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM nfc_logs WHERE synced = 0',
      ),
    ) ?? 0;
    final ticketCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM manual_tickets WHERE synced = 0',
      ),
    ) ?? 0;
    return nfcCount + ticketCount;
  }

  /// Helper: Convert DB row to NfcEvent
  NfcEvent _nfcLogFromRow(Map<String, dynamic> row) {
    return NfcEvent(
      offlineId: row['offline_id'] as String?,
      cardId: row['card_id'] as String,
      busId: row['bus_id'] as String,
      eventType: row['event_type'] as String,
      latitude: row['latitude'] as double,
      longitude: row['longitude'] as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    );
  }

  /// Helper: Convert DB row to ManualTicket
  ManualTicket _manualTicketFromRow(Map<String, dynamic> row) {
    return ManualTicket(
      offlineId: row['offline_id'] as String?,
      busId: row['bus_id'] as String,
      passengerCount: row['passenger_count'] as int,
      fare: row['fare'] as double,
      latitude: row['latitude'] as double,
      longitude: row['longitude'] as double,
      notes: row['notes'] as String?,
      seatNumber: row['seat_number'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    );
  }

  /// Generate unique offline ID
  String _generateOfflineId() {
    return 'offline-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecondsSinceEpoch}';
  }
}
