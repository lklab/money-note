// record_storage.dart
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// 수입/지출
enum RecordKind { income, expense }

int _kindToInt(RecordKind k) => k == RecordKind.income ? 0 : 1;
RecordKind _intToKind(int v) => v == 0 ? RecordKind.income : RecordKind.expense;

class Record {
  final String id;           // uuid
  final DateTime dateTime;   // 거래 시각
  final RecordKind kind;     // 수입/지출
  final String budget;          // int
  final int amount;          // int64 (Dart int 사용)
  final String content;      // 내용
  final String memo;         // 메모

  const Record({
    required this.id,
    required this.dateTime,
    required this.kind,
    required this.budget,
    required this.amount,
    required this.content,
    required this.memo,
  });

  Record copyWith({
    String? id,
    DateTime? dateTime,
    RecordKind? kind,
    String? budget,
    int? amount,
    String? content,
    String? memo,
  }) {
    return Record(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      kind: kind ?? this.kind,
      budget: budget ?? this.budget,
      amount: amount ?? this.amount,
      content: content ?? this.content,
      memo: memo ?? this.memo,
    );
  }

  @override
  String toString() {
    return 'id=$id\ndateTime=$dateTime\nkind=$kind\nbudget=$budget\namount=$amount\ncontent=$content\nmemo=$memo';
  }
}

class RecordStorage {
  static final RecordStorage _instance = RecordStorage._internal();
  factory RecordStorage() => _instance;
  RecordStorage._internal();

  Database? _db;

  // ---------- Public API ----------

  /// 앱 시작 시 1회 호출
  Future<void> init() async {
    if (_db != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}${Platform.pathSeparator}ledger.sqlite';

    _db = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        // 성능 향상
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.rawQuery('PRAGMA synchronous = NORMAL');
        await db.rawQuery('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // records 테이블
        await db.execute('''
          CREATE TABLE records (
            id TEXT PRIMARY KEY,
            dateTime INTEGER NOT NULL,
            monthKey INTEGER NOT NULL,
            kind INTEGER NOT NULL,      -- 0: income, 1: expense
            budget TEXT NOT NULL,
            amount INTEGER NOT NULL,    -- 64-bit int
            content TEXT NOT NULL,
            memo TEXT NOT NULL
          );
        ''');

        // monthKey/날짜 인덱스 (월별 조회 + 정렬)
        await db.execute('CREATE INDEX idx_records_monthKey ON records(monthKey);');
        await db.execute('CREATE INDEX idx_records_dateTime ON records(dateTime);');

        // 월별 마감액
        await db.execute('''
          CREATE TABLE month_closings (
            monthKey INTEGER PRIMARY KEY,
            closing INTEGER NOT NULL
          );
        ''');
      },
    );

    // 로드시 마감 금액 일관성 보정
    await _ensureClosingsOnLoad();
  }

  /// 특정 월(yyyy-MM)의 내역 (날짜 오름차순)
  Future<List<Record>> getRecordsOfMonth(DateTime month) async {
    final db = _requireDb();
    final mk = _monthKey(month);
    final rows = await db.query(
      'records',
      where: 'monthKey = ?',
      whereArgs: [mk],
      orderBy: 'dateTime ASC',
    );
    return rows.map(_rowToRecord).toList();
  }

  /// 내역 추가
  Future<Record> addRecord({
    String? id,
    required DateTime dateTime,
    required RecordKind kind,
    required String budget,
    required int amount,
    required String content,
    required String memo,
  }) async {
    final db = _requireDb();
    final rid = id ?? const Uuid().v4();
    final mk = _monthKey(dateTime);

    await db.transaction((txn) async {
      await txn.insert('records', {
        'id': rid,
        'dateTime': dateTime.millisecondsSinceEpoch,
        'monthKey': mk,
        'kind': _kindToInt(kind),
        'budget': budget,
        'amount': amount,
        'content': content,
        'memo': memo,
      });

      // 변경 즉시 마감금액 재계산
      await _recomputeClosingsFromMonthKeyTxn(txn, mk);
    });

    return Record(
      id: rid,
      dateTime: dateTime,
      kind: kind,
      budget: budget,
      amount: amount,
      content: content,
      memo: memo,
    );
  }

  /// 특정 id 수정 (부분 갱신)
  Future<Record?> updateRecord(
    String id, {
    DateTime? dateTime,
    RecordKind? kind,
    String? budget,
    int? amount,
    String? content,
    String? memo,
  }) async {
    final db = _requireDb();

    Record? updated;
    await db.transaction((txn) async {
      final oldRow = await txn.query('records', where: 'id = ?', whereArgs: [id], limit: 1);
      if (oldRow.isEmpty) return;

      final old = _rowToRecord(oldRow.first);
      final newDateTime = dateTime ?? old.dateTime;
      final newMonth = _monthKey(newDateTime);
      final oldMonth = _monthKey(old.dateTime);

      final startMk = oldMonth < newMonth ? oldMonth : newMonth;

      final newValues = {
        'dateTime': newDateTime.millisecondsSinceEpoch,
        'monthKey': newMonth,
        'kind': _kindToInt(kind ?? old.kind),
        'budget': budget ?? old.budget,
        'amount': amount ?? old.amount,
        'content': content ?? old.content,
        'memo': memo ?? old.memo,
      };

      await txn.update('records', newValues, where: 'id = ?', whereArgs: [id]);

      // 수정 전/후 중 오래된 월부터 재계산
      await _recomputeClosingsFromMonthKeyTxn(txn, startMk);

      updated = Record(
        id: id,
        dateTime: newDateTime,
        kind: kind ?? old.kind,
        budget: budget ?? old.budget,
        amount: amount ?? old.amount,
        content: content ?? old.content,
        memo: memo ?? old.memo,
      );
    });

    return updated;
  }

  /// 특정 id 삭제
  Future<bool> deleteRecord(String id) async {
    final db = _requireDb();
    var ok = false;

    await db.transaction((txn) async {
      final oldRow = await txn.query('records', where: 'id = ?', whereArgs: [id], limit: 1);
      if (oldRow.isEmpty) return;

      final old = _rowToRecord(oldRow.first);
      final oldMonth = _monthKey(old.dateTime);

      final cnt = await txn.delete('records', where: 'id = ?', whereArgs: [id]);
      ok = cnt > 0;

      if (ok) {
        await _recomputeClosingsFromMonthKeyTxn(txn, oldMonth);
      }
    });

    return ok;
  }

  /// 월 마감금액 조회(규칙 반영)
  Future<int> getClosingOfMonth(DateTime month) async {
    final db = _requireDb();
    final mk = _monthKey(month);
    final currentMk = _monthKey(DateTime.now());

    // 미래월: 현재월 반환 (저장 안 함)
    if (mk > currentMk) {
      final cur = await db.query('month_closings',
          where: 'monthKey = ?', whereArgs: [currentMk], limit: 1);
      return cur.isNotEmpty ? (cur.first['closing'] as int) : 0;
    }

    // 레코드 없으면 현재월=0 저장 후 0 반환
    if (!await _hasAnyRecord()) {
      await _ensureCurrentMonthZeroIfEmpty();
      final cur = await db.query('month_closings',
          where: 'monthKey = ?', whereArgs: [currentMk], limit: 1);
      return cur.isNotEmpty ? (cur.first['closing'] as int) : 0;
    }

    // 가장 오래된 내역보다 이전 월이면 0
    final oldestMk = await _getOldestRecordMonthKey();
    if (oldestMk == null || mk < oldestMk) return 0;

    // 저장되어 있으면 바로 반환
    final row = await db.query('month_closings',
        where: 'monthKey = ?', whereArgs: [mk], limit: 1);
    if (row.isNotEmpty) return row.first['closing'] as int;

    // 누락 시, 해당 월부터 현재월까지 채운 뒤 반환
    await _recomputeClosingsFromMonthKey(mk);
    final row2 = await db.query('month_closings',
        where: 'monthKey = ?', whereArgs: [mk], limit: 1);
    return row2.isNotEmpty ? (row2.first['closing'] as int) : 0;
  }

  // ---------- Internals ----------

  Database _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError('RecordStorage.init()을 먼저 호출하세요.');
    }
    return db;
  }

  int _monthKey(DateTime dt) => dt.year * 100 + dt.month;

  int _prevMonthKey(int mk) {
    final y = mk ~/ 100;
    final m = mk % 100;
    return (m == 1) ? (y - 1) * 100 + 12 : y * 100 + (m - 1);
  }

  int _nextMonthKey(int mk) {
    final y = mk ~/ 100;
    final m = mk % 100;
    return (m == 12) ? (y + 1) * 100 + 1 : y * 100 + (m + 1);
  }

  Record _rowToRecord(Map<String, Object?> row) {
    return Record(
      id: row['id'] as String,
      dateTime: DateTime.fromMillisecondsSinceEpoch(row['dateTime'] as int),
      kind: _intToKind(row['kind'] as int),
      budget: row['budget'] as String,
      amount: row['amount'] as int,
      content: row['content'] as String,
      memo: row['memo'] as String,
    );
  }

  Future<bool> _hasAnyRecord() async {
    final db = _requireDb();
    final res = await db.rawQuery('SELECT EXISTS(SELECT 1 FROM records LIMIT 1) AS e;');
    return (res.first['e'] as int) == 1;
    }

  Future<int?> _getOldestRecordMonthKey() async {
    final db = _requireDb();
    final row = await db.query('records', orderBy: 'dateTime ASC', limit: 1);
    if (row.isEmpty) return null;
    return row.first['monthKey'] as int;
  }

  Future<void> _ensureCurrentMonthZeroIfEmpty() async {
    final db = _requireDb();
    final currentMk = _monthKey(DateTime.now());
    await db.insert(
      'month_closings',
      {'monthKey': currentMk, 'closing': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 앱 로드시 일관성 확보
  Future<void> _ensureClosingsOnLoad() async {
    final db = _requireDb();
    final currentMk = _monthKey(DateTime.now());

    if (!await _hasAnyRecord()) {
      await _ensureCurrentMonthZeroIfEmpty();
      return;
    }

    final cur = await db.query('month_closings',
        where: 'monthKey = ?', whereArgs: [currentMk], limit: 1);
    if (cur.isNotEmpty) return; // 최신 상태

    // 전월부터 과거로 내려가며 anchor(저장된 마감금액) 탐색
    int cursor = _prevMonthKey(currentMk);
    Map<String, Object?>? anchor;
    while (true) {
      final found = await db.query('month_closings',
          where: 'monthKey = ?', whereArgs: [cursor], limit: 1);
      if (found.isNotEmpty) {
        anchor = found.first;
        break;
      }
      final oldestMk = await _getOldestRecordMonthKey();
      if (oldestMk == null || cursor < oldestMk) break;
      cursor = _prevMonthKey(cursor);
    }

    int start;
    int base;
    if (anchor != null) {
      start = _nextMonthKey(anchor['monthKey'] as int);
      base = anchor['closing'] as int;
    } else {
      start = (await _getOldestRecordMonthKey()) ?? currentMk;
      base = 0;
    }

    await _recomputeRange(start, currentMk, base);
  }

  /// 외부 트랜잭션 없이 시작 월부터 현재월까지 재계산
  Future<void> _recomputeClosingsFromMonthKey(int startMk) async {
    final db = _requireDb();
    await db.transaction((txn) async {
      await _recomputeClosingsFromMonthKeyTxn(txn, startMk);
    });
  }

  /// 트랜잭션 내부: 시작 월부터 현재월까지 재계산
  Future<void> _recomputeClosingsFromMonthKeyTxn(DatabaseExecutor txn, int startMk) async {
    final currentMk = _monthKey(DateTime.now());

    // 레코드 없으면 현재월 0 저장
    final res = await txn.rawQuery('SELECT EXISTS(SELECT 1 FROM records LIMIT 1) AS e;');
    final hasRecords = (res.first['e'] as int) == 1;
    if (!hasRecords) {
      await txn.insert(
        'month_closings',
        {'monthKey': currentMk, 'closing': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return;
    }

    // 시작 지점 보정
    final oldestRow =
        await txn.query('records', orderBy: 'dateTime ASC', limit: 1);
    if (oldestRow.isEmpty) {
      await txn.insert(
        'month_closings',
        {'monthKey': currentMk, 'closing': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return;
    }
    final oldestMk = oldestRow.first['monthKey'] as int;
    int start = startMk < oldestMk ? oldestMk : startMk;

    // 시작 월의 전월 마감 탐색
    final prev = _prevMonthKey(start);
    final prevClosing = await txn.query('month_closings',
        where: 'monthKey = ?', whereArgs: [prev], limit: 1);
    int base;
    if (prevClosing.isNotEmpty) {
      base = prevClosing.first['closing'] as int;
    } else if (prev < oldestMk) {
      base = 0;
    } else {
      start = oldestMk;
      base = 0;
    }

    await _recomputeRangeTxn(txn, start, currentMk, base);
  }

  /// 트랜잭션 내부: [startMk] ~ [endMk] 구간 재계산/저장
  Future<void> _recomputeRangeTxn(
      DatabaseExecutor txn, int startMk, int endMk, int base) async {
    int mk = startMk;
    int carry = base;

    while (mk <= endMk) {
      final incomeRow = await txn.rawQuery(
        'SELECT IFNULL(SUM(amount), 0) AS s FROM records WHERE monthKey = ? AND kind = 0;',
        [mk],
      );
      final expenseRow = await txn.rawQuery(
        'SELECT IFNULL(SUM(amount), 0) AS s FROM records WHERE monthKey = ? AND kind = 1;',
        [mk],
      );
      final incomes = (incomeRow.first['s'] as int);
      final expenses = (expenseRow.first['s'] as int);
      final closing = carry + incomes - expenses;

      await txn.insert(
        'month_closings',
        {'monthKey': mk, 'closing': closing},
        conflictAlgorithm: ConflictAlgorithm.replace, // upsert
      );

      carry = closing;
      mk = _nextMonthKey(mk);
    }
  }

  /// 외부 트랜잭션: 범위 재계산
  Future<void> _recomputeRange(int startMk, int endMk, int base) async {
    final db = _requireDb();
    await db.transaction((txn) async {
      await _recomputeRangeTxn(txn, startMk, endMk, base);
    });
  }
}
