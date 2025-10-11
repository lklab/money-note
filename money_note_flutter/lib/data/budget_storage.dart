// budget_storage.dart
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// 수입/지출
enum BudgetKind { income, expense }
int _kindToInt(BudgetKind k) => k == BudgetKind.income ? 0 : 1;
BudgetKind _intToKind(int v) => v == 0 ? BudgetKind.income : BudgetKind.expense;

int budgetKindToInt(BudgetKind k) => _kindToInt(k);
BudgetKind intToBudgetKind(int v) => _intToKind(v);

/// 현금/자본
enum BudgetAssetType { cash, capital }
int _assetToInt(BudgetAssetType t) => t == BudgetAssetType.cash ? 0 : 1;
BudgetAssetType _intToAsset(int v) => v == 0 ? BudgetAssetType.cash : BudgetAssetType.capital;

int budgetAssetTypeToInt(BudgetAssetType t) => _assetToInt(t);
BudgetAssetType intToBudgetAssetType(int v) => _intToAsset(v);

/// Domain models (앱 내부에서 사용)
class Budget {
  final String id;
  final String name;
  final BudgetKind kind;          // 수입/지출
  final BudgetAssetType assetType; // 현금/자본
  final int amount;               // int64

  const Budget({
    required this.id,
    required this.name,
    required this.kind,
    required this.assetType,
    required this.amount,
  });

  Budget copyWith({
    String? id,
    String? name,
    BudgetKind? kind,
    BudgetAssetType? assetType,
    int? amount,
  }) => Budget(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    assetType: assetType ?? this.assetType,
    amount: amount ?? this.amount,
  );
}

class BudgetGroup {
  final String id;
  final String name;
  final List<Budget> budgets; // 해당 월에서의 순서대로

  const BudgetGroup({
    required this.id,
    required this.name,
    required this.budgets,
  });

  BudgetGroup copyWith({String? id, String? name, List<Budget>? budgets}) =>
      BudgetGroup(id: id ?? this.id, name: name ?? this.name, budgets: budgets ?? this.budgets);
}

class MonthlyBudget {
  final int monthKey; // yyyyMM
  final List<BudgetGroup> groups; // 순서대로

  const MonthlyBudget({
    required this.monthKey,
    required this.groups,
  });

  MonthlyBudget copyWith({int? monthKey, List<BudgetGroup>? groups}) =>
      MonthlyBudget(monthKey: monthKey ?? this.monthKey, groups: groups ?? this.groups);
}

class BudgetStorage {
  static final BudgetStorage _instance = BudgetStorage._internal();
  factory BudgetStorage() => _instance;
  BudgetStorage._internal();

  Database? _db;

  bool _isDirty = false;
  bool get isDirty => _isDirty;

  void clearDirty() {
    _isDirty = false;
  }

  // ===================== Public API =====================

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}${Platform.pathSeparator}budget.sqlite';

    _db = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.rawQuery('PRAGMA synchronous = NORMAL');
        await db.rawQuery('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // 예산(전역 엔티티)
        await db.execute('''
          CREATE TABLE budgets (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            kind INTEGER NOT NULL,        -- 0 income, 1 expense
            assetType INTEGER NOT NULL,   -- 0 cash, 1 capital
            amount INTEGER NOT NULL
          );
        ''');

        // 예산그룹(전역 엔티티)
        await db.execute('''
          CREATE TABLE budget_groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL
          );
        ''');

        // 월간 예산(월 존재 여부만 표시)
        await db.execute('''
          CREATE TABLE monthly_budgets (
            monthKey INTEGER PRIMARY KEY   -- yyyyMM
          );
        ''');

        // 월간 예산 내 그룹 순서(월별)
        await db.execute('''
          CREATE TABLE monthly_budget_groups (
            monthKey INTEGER NOT NULL,
            groupId TEXT NOT NULL,
            position INTEGER NOT NULL,
            PRIMARY KEY (monthKey, groupId),
            FOREIGN KEY (monthKey) REFERENCES monthly_budgets(monthKey) ON DELETE CASCADE,
            FOREIGN KEY (groupId) REFERENCES budget_groups(id) ON DELETE CASCADE
          );
        ''');
        await db.execute('CREATE INDEX idx_mbg_month ON monthly_budget_groups(monthKey);');

        // 월간 예산 내 각 그룹의 예산 순서(월별)
        await db.execute('''
          CREATE TABLE group_budgets (
            monthKey INTEGER NOT NULL,
            groupId TEXT NOT NULL,
            budgetId TEXT NOT NULL,
            position INTEGER NOT NULL,
            PRIMARY KEY (monthKey, groupId, budgetId),
            FOREIGN KEY (monthKey) REFERENCES monthly_budgets(monthKey) ON DELETE CASCADE,
            FOREIGN KEY (groupId) REFERENCES budget_groups(id) ON DELETE CASCADE,
            FOREIGN KEY (budgetId) REFERENCES budgets(id) ON DELETE CASCADE
          );
        ''');
        await db.execute('CREATE INDEX idx_gb_month_group ON group_budgets(monthKey, groupId);');
        await db.execute('CREATE INDEX idx_gb_budget ON group_budgets(budgetId);');
      },
    );
  }

  // 4. 특정 월의 월간 예산 조회 (ID를 실제 엔티티로 풀어주고, 없는 ID는 무시)
  Future<MonthlyBudget> getMonthlyBudget(DateTime month) async {
    final db = _requireDb();
    final mk = _monthKey(month);

    // 월 없으면 빈 MonthlyBudget 반환 (저장까지는 하지 않음)
    final mb = await db.query('monthly_budgets', where: 'monthKey = ?', whereArgs: [mk], limit: 1);
    if (mb.isEmpty) {
      return MonthlyBudget(monthKey: mk, groups: const []);
    }

    // 그룹 순서 조회
    final groupRows = await db.query(
      'monthly_budget_groups',
      columns: ['groupId'],
      where: 'monthKey = ?',
      whereArgs: [mk],
      orderBy: 'position ASC',
    );

    final List<BudgetGroup> groups = [];
    for (final gr in groupRows) {
      final gid = gr['groupId'] as String;

      // 그룹 엔티티가 없으면 skip
      final groupEnt = await db.query('budget_groups', where: 'id = ?', whereArgs: [gid], limit: 1);
      if (groupEnt.isEmpty) continue;
      final gName = groupEnt.first['name'] as String;

      // 예산 목록 (해당 월+그룹에서의 순서)
      final gbRows = await db.query(
        'group_budgets',
        columns: ['budgetId'],
        where: 'monthKey = ? AND groupId = ?',
        whereArgs: [mk, gid],
        orderBy: 'position ASC',
      );

      final List<Budget> budgets = [];
      for (final br in gbRows) {
        final bid = br['budgetId'] as String;
        final bEnt = await db.query('budgets', where: 'id = ?', whereArgs: [bid], limit: 1);
        if (bEnt.isEmpty) continue; // 누락된 ID는 무시
        budgets.add(_rowToBudget(bEnt.first));
      }

      groups.add(BudgetGroup(id: gid, name: gName, budgets: budgets));
    }

    return MonthlyBudget(monthKey: mk, groups: groups);
  }

  // 3. 새로운 예산 추가 (예산 데이터 + 그룹ID + 연월)
  Future<Budget> addBudget({
    required String name,
    required BudgetKind kind,
    required BudgetAssetType assetType,
    required int amount,
    required String groupId,
    required DateTime month,
  }) async {
    final db = _requireDb();
    final mk = _monthKey(month);
    final bid = const Uuid().v4();

    await db.transaction((txn) async {
      // 예산 엔티티 생성
      await txn.insert('budgets', {
        'id': bid,
        'name': name,
        'kind': _kindToInt(kind),
        'assetType': _assetToInt(assetType),
        'amount': amount,
      });

      // 월간예산/그룹 포함 보장
      await _ensureMonthlyBudgetTxn(txn, mk);
      await _ensureGroupIncludedInMonthTxn(txn, mk, groupId);

      // 해당 그룹의 마지막 위치+1
      final pos = await _nextBudgetPositionInGroupTxn(txn, mk, groupId);

      await txn.insert('group_budgets', {
        'monthKey': mk,
        'groupId': groupId,
        'budgetId': bid,
        'position': pos,
      });
    });

    _isDirty = true;
    return Budget(
      id: bid,
      name: name,
      kind: kind,
      assetType: assetType,
      amount: amount,
    );
  }

  // 4. 예산 수정/삭제
  Future<Budget?> updateBudget(
    String budgetId, {
    String? name,
    BudgetKind? kind,
    BudgetAssetType? assetType,
    int? amount,
  }) async {
    final db = _requireDb();

    final row = await db.query('budgets', where: 'id = ?', whereArgs: [budgetId], limit: 1);
    if (row.isEmpty) return null;

    final cur = _rowToBudget(row.first);
    final newMap = {
      'name': name ?? cur.name,
      'kind': _kindToInt(kind ?? cur.kind),
      'assetType': _assetToInt(assetType ?? cur.assetType),
      'amount': amount ?? cur.amount,
    };

    await db.update('budgets', newMap, where: 'id = ?', whereArgs: [budgetId]);

    final after = await db.query('budgets', where: 'id = ?', whereArgs: [budgetId], limit: 1);

    _isDirty = true;
    return _rowToBudget(after.first);
  }

  /// 예산 삭제 (해당 월과 그룹의 연결도 제거)
  /// - groupId, month 필수: 그 월의 그룹 리스트에서 제거
  /// - 예산이 다른 월/그룹에서 더 이상 사용되지 않으면 budgets 엔티티도 삭제
  Future<bool> deleteBudget({
    required String budgetId,
    required String groupId,
    required DateTime month,
  }) async {
    final db = _requireDb();
    final mk = _monthKey(month);
    var ok = false;

    await db.transaction((txn) async {
      // 월/그룹 연결 제거
      final cnt = await txn.delete(
        'group_budgets',
        where: 'monthKey = ? AND groupId = ? AND budgetId = ?',
        whereArgs: [mk, groupId, budgetId],
      );
      if (cnt == 0) {
        ok = false;
        return;
      }
      ok = true;

      // 동일 그룹 내 position 압축(간격 없애기)
      await _compactBudgetPositionsInGroupTxn(txn, mk, groupId);

      // budgetId가 더 이상 어떤 월/그룹에도 연결되지 않으면 budgets 삭제(고아 정리)
      final remain = await txn.query(
        'group_budgets',
        where: 'budgetId = ?',
        whereArgs: [budgetId],
        limit: 1,
      );
      if (remain.isEmpty) {
        await txn.delete('budgets', where: 'id = ?', whereArgs: [budgetId]);
      }
    });

    _isDirty = true;
    return ok;
  }

  // 5. 예산그룹 추가 (월 자동 생성)
  Future<String> addBudgetGroup({
    required String name,
    required DateTime month,
  }) async {
    final db = _requireDb();
    final mk = _monthKey(month);
    final gid = const Uuid().v4();

    await db.transaction((txn) async {
      await txn.insert('budget_groups', {'id': gid, 'name': name});

      await _ensureMonthlyBudgetTxn(txn, mk);
      final pos = await _nextGroupPositionInMonthTxn(txn, mk);
      await txn.insert('monthly_budget_groups', {
        'monthKey': mk,
        'groupId': gid,
        'position': pos,
      });
    });

    _isDirty = true;
    return gid;
  }

  // 6. 예산그룹 수정 또는 삭제
  Future<bool> updateBudgetGroupName(String groupId, String newName) async {
    final db = _requireDb();
    final cnt =
        await db.update('budget_groups', {'name': newName}, where: 'id = ?', whereArgs: [groupId]);

    _isDirty = true;
    return cnt > 0;
  }

  /// 해당 그룹에 포함된 예산이 하나도 없을 경우에만 삭제 가능
  /// 삭제 시 연월도 받아, 그 월의 그룹 리스트에서 제거
  Future<bool> deleteBudgetGroup({
    required String groupId,
    required DateTime month,
  }) async {
    final db = _requireDb();
    final mk = _monthKey(month);
    var ok = false;

    await db.transaction((txn) async {
      // 이 월의 이 그룹에 예산이 있는지 확인
      final hasBudget = await txn.query(
        'group_budgets',
        where: 'monthKey = ? AND groupId = ?',
        whereArgs: [mk, groupId],
        limit: 1,
      );
      if (hasBudget.isNotEmpty) {
        ok = false;
        return;
      }

      // 월의 그룹 연결 제거
      final linkCnt = await txn.delete(
        'monthly_budget_groups',
        where: 'monthKey = ? AND groupId = ?',
        whereArgs: [mk, groupId],
      );
      if (linkCnt == 0) {
        ok = false;
        return;
      }

      // 해당 월의 그룹 position 압축
      await _compactGroupPositionsInMonthTxn(txn, mk);

      // 이 그룹이 다른 월에서 사용되는지 확인
      final stillUsed = await txn.query(
        'monthly_budget_groups',
        where: 'groupId = ?',
        whereArgs: [groupId],
        limit: 1,
      );
      if (stillUsed.isEmpty) {
        // 전역 그룹 엔티티 제거 (고아 정리)
        await txn.delete('budget_groups', where: 'id = ?', whereArgs: [groupId]);
      }

      ok = true;
    });

    _isDirty = true;
    return ok;
  }

  // 7. 예산 이동(같은 월 내에서 다른 그룹 혹은 동일 그룹 내 위치 변경)
  Future<void> moveBudget({
    required DateTime month,
    required String budgetId,
    required String fromGroupId,
    required String toGroupId,
    required int toIndex, // 0-based, toGroup 내에서의 목표 위치
  }) async {
    final db = _requireDb();
    final mk = _monthKey(month);

    await db.transaction((txn) async {
      // 보호: 월/그룹 포함 보장
      await _ensureMonthlyBudgetTxn(txn, mk);
      await _ensureGroupIncludedInMonthTxn(txn, mk, toGroupId);

      // fromGroup에서 제거
      await txn.delete(
        'group_budgets',
        where: 'monthKey = ? AND groupId = ? AND budgetId = ?',
        whereArgs: [mk, fromGroupId, budgetId],
      );
      await _compactBudgetPositionsInGroupTxn(txn, mk, fromGroupId);

      // toGroup에서 toIndex로 삽입: 뒤에 것들 position+1
      await _shiftBudgetPositionsDownFromTxn(txn, mk, toGroupId, toIndex);
      await txn.insert('group_budgets', {
        'monthKey': mk,
        'groupId': toGroupId,
        'budgetId': budgetId,
        'position': toIndex,
      });
    });

    _isDirty = true;
  }

  // 8. 예산그룹 이동(같은 월 내에서 순서 변경)
  Future<void> moveGroup({
    required DateTime month,
    required String groupId,
    required int toIndex, // 0-based
  }) async {
    final db = _requireDb();
    final mk = _monthKey(month);

    await db.transaction((txn) async {
      // 현재 position
      final cur = await txn.query(
        'monthly_budget_groups',
        where: 'monthKey = ? AND groupId = ?',
        whereArgs: [mk, groupId],
        limit: 1,
      );
      if (cur.isEmpty) return;
      final curPos = cur.first['position'] as int;

      if (toIndex == curPos) return;

      if (toIndex < curPos) {
        // 사이 [toIndex, curPos-1] +1
        await txn.rawUpdate(
          '''
          UPDATE monthly_budget_groups
          SET position = position + 1
          WHERE monthKey = ? AND position >= ? AND position < ?;
          ''',
          [mk, toIndex, curPos],
        );
      } else {
        // 사이 [curPos+1, toIndex] -1
        await txn.rawUpdate(
          '''
          UPDATE monthly_budget_groups
          SET position = position - 1
          WHERE monthKey = ? AND position > ? AND position <= ?;
          ''',
          [mk, curPos, toIndex],
        );
      }

      await txn.update(
        'monthly_budget_groups',
        {'position': toIndex},
        where: 'monthKey = ? AND groupId = ?',
        whereArgs: [mk, groupId],
      );
    });

    _isDirty = true;
  }

  // 9. 월간예산 없을 때: 다른 월에서 복사(새 ID 생성)
  Future<void> cloneMonthlyBudget({
    required DateTime fromMonth,
    required DateTime toMonth,
  }) async {
    final db = _requireDb();
    final fromMk = _monthKey(fromMonth);
    final toMk = _monthKey(toMonth);

    await db.transaction((txn) async {
      // 이미 있으면 skip
      final exists = await txn.query('monthly_budgets', where: 'monthKey = ?', whereArgs: [toMk]);
      if (exists.isNotEmpty) return;

      // fromMonth 데이터 읽기
      final fromGroups = await txn.query(
        'monthly_budget_groups',
        where: 'monthKey = ?',
        whereArgs: [fromMk],
        orderBy: 'position ASC',
      );

      // 대상 월 생성
      await txn.insert('monthly_budgets', {'monthKey': toMk});

      // 매핑: 원본 그룹ID -> 새 그룹ID
      final Map<String, String> groupIdMap = {};
      // 매핑: 원본 예산ID -> 새 예산ID
      final Map<String, String> budgetIdMap = {};

      int gPos = 0;
      for (final g in fromGroups) {
        final oldGid = g['groupId'] as String;
        // 그룹 엔티티 로드
        final gEnt =
            await txn.query('budget_groups', where: 'id = ?', whereArgs: [oldGid], limit: 1);
        if (gEnt.isEmpty) continue;
        final gName = gEnt.first['name'] as String;

        // 새 그룹 생성
        final newGid = const Uuid().v4();
        groupIdMap[oldGid] = newGid;
        await txn.insert('budget_groups', {'id': newGid, 'name': gName});

        // 대상 월에 그룹 추가
        await txn.insert('monthly_budget_groups', {
          'monthKey': toMk,
          'groupId': newGid,
          'position': gPos++,
        });

        // 그룹의 예산들 로드
        final gbRows = await txn.query(
          'group_budgets',
          where: 'monthKey = ? AND groupId = ?',
          whereArgs: [fromMk, oldGid],
          orderBy: 'position ASC',
        );

        int bPos = 0;
        for (final br in gbRows) {
          final oldBid = br['budgetId'] as String;
          // 예산 엔티티 로드
          final bEnt = await txn.query('budgets', where: 'id = ?', whereArgs: [oldBid], limit: 1);
          if (bEnt.isEmpty) continue;

          // 새 예산 생성 (id 새로)
          final newBid = budgetIdMap.putIfAbsent(oldBid, () => const Uuid().v4());
          final b = bEnt.first;
          await txn.insert('budgets', {
            'id': newBid,
            'name': b['name'],
            'kind': b['kind'],
            'assetType': b['assetType'],
            'amount': b['amount'],
          });

          // 대상 월/그룹에 예산 추가
          await txn.insert('group_budgets', {
            'monthKey': toMk,
            'groupId': newGid,
            'budgetId': newBid,
            'position': bPos++,
          });
        }
      }
    });

    _isDirty = true;
  }

  /// 전달된 MonthlyBudget 리스트를 규칙에 따라 한 번에 저장/병합한다.
  /// 규칙:
  /// 1) 동일 monthKey가 이미 있으면 그룹만 합치고(append), 없으면 월 생성 후 삽입
  /// 2) 같은 월에 같은 groupId가 있으면 그 그룹의 budgets만 합치기(append)
  /// 3) 다른 월에서 이미 사용 중인 groupId는 무시
  /// 4) budgets 테이블에 이미 존재하는 budgetId는 무시(링크도 추가하지 않음)
  Future<void> importMonthlyBudgetsMerged(List<MonthlyBudget> items) async {
    if (items.isEmpty) return;

    final db = _requireDb();

    await db.transaction((txn) async {
      for (final mb in items) {
        final mk = mb.monthKey;

        // (1) 월 존재 보장 (있으면 무시)
        await txn.insert(
          'monthly_budgets',
          {'monthKey': mk},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // 현재 월의 마지막 그룹 position 구하기(append용)
        Future<int> nextGroupPos() => _nextGroupPositionInMonthTxn(txn, mk);

        for (final group in mb.groups) {
          final gid = group.id;

          // (3) 다른 월에 같은 groupId가 이미 존재하면 SKIP
          final usedElsewhere = await _groupUsedInOtherMonthTxn(txn, gid, mk);
          if (usedElsewhere) {
            // skip this group entirely
            continue;
          }

          // 그룹 엔티티 존재 보장(없으면 생성, 있으면 이름은 갱신하지 않음)
          final groupRow = await txn.query(
            'budget_groups',
            where: 'id = ?',
            whereArgs: [gid],
            limit: 1,
          );
          if (groupRow.isEmpty) {
            await txn.insert('budget_groups', {'id': gid, 'name': group.name});
          }

          // (1,2) 월-그룹 링크 존재 보장(없으면 append로 추가)
          final link = await txn.query(
            'monthly_budget_groups',
            where: 'monthKey = ? AND groupId = ?',
            whereArgs: [mk, gid],
            limit: 1,
          );
          if (link.isEmpty) {
            final pos = await nextGroupPos();
            await txn.insert('monthly_budget_groups', {
              'monthKey': mk,
              'groupId': gid,
              'position': pos,
            });
          }

          // 이 그룹 안에서 budgets append용 position 헬퍼
          Future<int> nextBudgetPos() => _nextBudgetPositionInGroupTxn(txn, mk, gid);

          // (2,4) 예산 병합: budgets 테이블에 같은 id가 있으면 무시, 없으면 생성 + 링크 append
          for (final b in group.budgets) {
            final exists = await _budgetIdExistsTxn(txn, b.id);
            if (exists) {
              // 규칙 4: 동일 id 존재 -> 완전히 무시(링크도 추가하지 않음)
              continue;
            }

            // budgets 엔티티 생성
            await txn.insert('budgets', {
              'id': b.id,
              'name': b.name,
              'kind': _kindToInt(b.kind),
              'assetType': _assetToInt(b.assetType),
              'amount': b.amount,
            });

            // group_budgets 링크 append (해당 월/그룹의 맨 뒤)
            final bpos = await nextBudgetPos();
            await txn.insert('group_budgets', {
              'monthKey': mk,
              'groupId': gid,
              'budgetId': b.id,
              'position': bpos,
            });
          }
        }
      }
    });

    _isDirty = true;
  }

  // ====== 보조 쿼리 ======

  /// budgets 테이블에 해당 budgetId가 존재하는지(전역) 확인
  Future<bool> _budgetIdExistsTxn(DatabaseExecutor txn, String budgetId) async {
    final r = await txn.rawQuery(
      'SELECT 1 FROM budgets WHERE id = ? LIMIT 1;',
      [budgetId],
    );
    return r.isNotEmpty;
  }

  /// 같은 groupId가 다른 월(monthKey != mk)에서 이미 쓰였는지 확인
  Future<bool> _groupUsedInOtherMonthTxn(DatabaseExecutor txn, String groupId, int mk) async {
    final r = await txn.rawQuery(
      '''
      SELECT 1
      FROM monthly_budget_groups
      WHERE groupId = ? AND monthKey != ?
      LIMIT 1;
      ''',
      [groupId, mk],
    );
    return r.isNotEmpty;
  }

  // ===================== Internals =====================

  Database _requireDb() {
    final db = _db;
    if (db == null) throw StateError('BudgetStorage.init()을 먼저 호출하세요.');
    return db;
  }

  int _monthKey(DateTime dt) => dt.year * 100 + dt.month;

  Budget _rowToBudget(Map<String, Object?> row) => Budget(
        id: row['id'] as String,
        name: row['name'] as String,
        kind: _intToKind(row['kind'] as int),
        assetType: _intToAsset(row['assetType'] as int),
        amount: row['amount'] as int,
      );

  Future<void> _ensureMonthlyBudgetTxn(DatabaseExecutor txn, int mk) async {
    await txn.insert(
      'monthly_budgets',
      {'monthKey': mk},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _ensureGroupIncludedInMonthTxn(DatabaseExecutor txn, int mk, String groupId) async {
    final link = await txn.query(
      'monthly_budget_groups',
      where: 'monthKey = ? AND groupId = ?',
      whereArgs: [mk, groupId],
      limit: 1,
    );
    if (link.isNotEmpty) return;

    // 그룹 존재 확인
    final g = await txn.query('budget_groups', where: 'id = ?', whereArgs: [groupId], limit: 1);
    if (g.isEmpty) {
      // 그룹이 없다면 예외로 처리할 수도 있고, 자동 생성할 수도 있음.
      // 명세상 "예산그룹 추가"에서만 자동 생성하므로 여기선 에러로 처리.
      throw StateError('groupId가 존재하지 않습니다: $groupId');
    }

    final pos = await _nextGroupPositionInMonthTxn(txn, mk);
    await txn.insert('monthly_budget_groups', {
      'monthKey': mk,
      'groupId': groupId,
      'position': pos,
    });
  }

  Future<int> _nextGroupPositionInMonthTxn(DatabaseExecutor txn, int mk) async {
    final r = await txn.rawQuery(
      'SELECT IFNULL(MAX(position), -1) AS m FROM monthly_budget_groups WHERE monthKey = ?;',
      [mk],
    );
    final maxPos = (r.first['m'] as int);
    return maxPos + 1;
  }

  Future<int> _nextBudgetPositionInGroupTxn(DatabaseExecutor txn, int mk, String groupId) async {
    final r = await txn.rawQuery(
      'SELECT IFNULL(MAX(position), -1) AS m FROM group_budgets WHERE monthKey = ? AND groupId = ?;',
      [mk, groupId],
    );
    final maxPos = (r.first['m'] as int);
    return maxPos + 1;
  }

  Future<void> _compactBudgetPositionsInGroupTxn(
      DatabaseExecutor txn, int mk, String groupId) async {
    // position을 0..N-1로 재배열
    final rows = await txn.query(
      'group_budgets',
      where: 'monthKey = ? AND groupId = ?',
      whereArgs: [mk, groupId],
      orderBy: 'position ASC',
    );
    for (var i = 0; i < rows.length; i++) {
      final bid = rows[i]['budgetId'] as String;
      await txn.update(
        'group_budgets',
        {'position': i},
        where: 'monthKey = ? AND groupId = ? AND budgetId = ?',
        whereArgs: [mk, groupId, bid],
      );
    }
  }

  Future<void> _compactGroupPositionsInMonthTxn(DatabaseExecutor txn, int mk) async {
    final rows = await txn.query(
      'monthly_budget_groups',
      where: 'monthKey = ?',
      whereArgs: [mk],
      orderBy: 'position ASC',
    );
    for (var i = 0; i < rows.length; i++) {
      final gid = rows[i]['groupId'] as String;
      await txn.update(
        'monthly_budget_groups',
        {'position': i},
        where: 'monthKey = ? AND groupId = ?',
        whereArgs: [mk, gid],
      );
    }
  }

  Future<void> _shiftBudgetPositionsDownFromTxn(
      DatabaseExecutor txn, int mk, String groupId, int fromIndex) async {
    await txn.rawUpdate(
      '''
      UPDATE group_budgets
      SET position = position + 1
      WHERE monthKey = ? AND groupId = ? AND position >= ?;
      ''',
      [mk, groupId, fromIndex],
    );
  }
}
