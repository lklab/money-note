// lib/data/asset_storage.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// TODO
/// 로드 시 그룹 없으면 기본 그룹 하나 추가
/// 마지막 그룹은 삭제할 수 없음

/// ===== 모델 =====

class Asset {
  final int id;
  String name;
  bool tracking;
  int amount;
  String memo;

  Asset({
    required this.id,
    required this.name,
    required this.tracking,
    required this.amount,
    required this.memo,
  });

  factory Asset.fromJson(Map<String, dynamic> j) => Asset(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String,
    tracking: (j['tracking'] as bool?) ?? true,
    amount: (j['amount'] as num).toInt(),
    memo: (j['memo'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tracking': tracking,
    'amount': amount,
    'memo': memo,
  };

  Asset copy() => Asset(
    id: id,
    name: name,
    tracking: tracking,
    amount: amount,
    memo: memo,
  );
}

class AssetGroup {
  final int id; // 고유 id
  String name;
  final List<Asset> assets;

  AssetGroup({
    required this.id,
    required this.name,
    List<Asset>? assets,
  }) : assets = assets ?? <Asset>[];

  factory AssetGroup.fromJson(Map<String, dynamic> j) => AssetGroup(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String,
    assets: ((j['assets'] as List?) ?? const [])
        .map((e) => Asset.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'assets': assets.map((e) => e.toJson()).toList(),
  };

  AssetGroup copy() => AssetGroup(
    id: id,
    name: name,
    assets: assets.map((e) => e.copy()).toList(),
  );
}

/// 파일 포맷 버전
/// v1: id 없음 (이전 버전)
/// v2: id 및 nextId 포함
const _kStorageVersion = 2;

/// ===== 스토리지 =====
/// - JSON 로컬 파일에 전체 데이터를 저장/로드
/// - 모든 변경 즉시 저장
/// - 그룹/자산의 순서 유지 (리스트 순서가 곧 정렬순서)
class AssetStorage {
  AssetStorage._();
  static final AssetStorage instance = AssetStorage._();

  final List<AssetGroup> _groups = [];
  bool _loaded = false;

  // id 생성기 (파일에 함께 저장/로드)
  int _nextId = 1;

  /// 간단한 뮤텍스(연속 저장 직렬화)
  Future<void> _mutex = Future.value();

  /// 저장 파일 경로
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/assets_v$_kStorageVersion.json');
  }

  /// (1) load(): 로컬 스토리지에서 전체 자산그룹/자산 로드
  Future<void> load() async {
    if (_loaded) return;
    final f = await _file();
    if (await f.exists()) {
      try {
        final txt = await f.readAsString();
        final map = json.decode(txt) as Map<String, dynamic>;
        final ver = (map['version'] as int?) ?? 1;

        if (ver == 2) {
          _nextId = (map['nextId'] as num?)?.toInt() ?? 1;
          final list = (map['groups'] as List?) ?? const [];
          _groups
            ..clear()
            ..addAll(list.map((e) => AssetGroup.fromJson(e as Map<String, dynamic>)));
        } else if (ver == 1) {
          // 마이그레이션: id가 없던 파일 → 순서대로 id 부여
          final list = (map['groups'] as List?) ?? const [];
          final migrated = <AssetGroup>[];
          int idGen = 1;
          for (final raw in list) {
            final g = raw as Map<String, dynamic>;
            final name = g['name'] as String;
            final assets = ((g['assets'] as List?) ?? const []).map((e) {
              final a = e as Map<String, dynamic>;
              return Asset(
                id: idGen++,
                name: a['name'] as String,
                tracking: (a['tracking'] as bool?) ?? true,
                amount: (a['amount'] as num).toInt(),
                memo: (a['memo'] as String?) ?? '',
              );
            }).toList();
            migrated.add(AssetGroup(
              id: idGen++,
              name: name,
              assets: assets,
            ));
          }
          _groups
            ..clear()
            ..addAll(migrated);
          _nextId = idGen;
          // 다음 저장 시 v2로 저장됨
        } else {
          // 알 수 없는 버전: 새로 시작
          _groups.clear();
          _nextId = 1;
        }
      } catch (_) {
        // 손상된 경우: 백업으로 남겨두고 새로 시작
        if (await f.exists()) {
          final bak = File('${f.path}.corrupt_${DateTime.now().millisecondsSinceEpoch}.bak');
          await f.copy(bak.path);
        }
        _groups.clear();
        _nextId = 1;
      }
    } else {
      _groups.clear();
      _nextId = 1;
    }
    _loaded = true;
  }

  /// 내부 저장 (원자적 저장: temp -> rename)
  Future<void> _persist() async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');

    final payload = <String, dynamic>{
      'version': _kStorageVersion,
      'nextId': _nextId,
      'groups': _groups.map((g) => g.toJson()).toList(),
      'savedAt': DateTime.now().toIso8601String(),
    };
    final txt = const JsonEncoder.withIndent('  ').convert(payload);

    await tmp.writeAsString(txt, flush: true);
    if (await f.exists()) {
      await f.delete();
    }
    await tmp.rename(f.path);
  }

  /// (2) 전체 데이터 가져오기 (읽기 전용 뷰)
  UnmodifiableListView<AssetGroup> get groups => UnmodifiableListView(_groups);

  /// ===== ID 생성 =====
  int _genId() => _nextId++;

  /// ===== 그룹 유틸 =====
  int _indexOfGroupId(int groupId) {
    for (int i = 0; i < _groups.length; i++) {
      if (_groups[i].id == groupId) return i;
    }
    throw StateError('존재하지 않는 그룹 id: $groupId');
  }

  /// (그룹 내) 에셋 위치 찾기
  /// 반환: (groupIndex, assetIndex)
  (int, int) _locateAssetById(int assetId) {
    for (int gi = 0; gi < _groups.length; gi++) {
      final list = _groups[gi].assets;
      for (int ai = 0; ai < list.length; ai++) {
        if (list[ai].id == assetId) return (gi, ai);
      }
    }
    throw StateError('존재하지 않는 자산 id: $assetId');
  }

  /// 목표 그룹에서 beforeAssetId 앞 인덱스를 계산 (없으면 맨 뒤)
  int _calcInsertIndexByBeforeId(AssetGroup target, int? beforeAssetId) {
    if (beforeAssetId == null) return target.assets.length;
    final idx = target.assets.indexWhere((a) => a.id == beforeAssetId);
    if (idx == -1) {
      // 못 찾으면 맨 뒤로
      return target.assets.length;
    }
    return idx;
  }

  /// 그룹 재배치에서 beforeGroupId 앞 인덱스 계산 (없으면 맨 뒤)
  int _calcInsertIndexByBeforeGroupId(int? beforeGroupId) {
    if (beforeGroupId == null) return _groups.length;
    final idx = _groups.indexWhere((g) => g.id == beforeGroupId);
    if (idx == -1) return _groups.length;
    return idx;
  }

  /// ====== 그룹 관련 ======

  /// 그룹 추가 (맨 뒤 또는 beforeGroupId 앞에 삽입)
  Future<int> addGroup(String name, {int? insertBeforeGroupId}) async {
    await load();
    final g = AssetGroup(id: _genId(), name: name);
    await _runLocked(() async {
      final insertIdx = _calcInsertIndexByBeforeGroupId(insertBeforeGroupId);
      _groups.insert(insertIdx, g);
      await _persist();
    });
    return g.id;
  }

  /// 그룹 이름 수정
  Future<void> renameGroup(int groupId, String newName) async {
    await load();
    await _runLocked(() async {
      final gi = _indexOfGroupId(groupId);
      _groups[gi].name = newName;
      await _persist();
    });
  }

  /// 그룹 삭제 (비어있을 때만)
  Future<void> deleteGroupIfEmpty(int groupId) async {
    await load();
    await _runLocked(() async {
      final gi = _indexOfGroupId(groupId);
      if (_groups[gi].assets.isNotEmpty) {
        throw StateError('그룹에 자산이 있어 삭제할 수 없습니다.');
      }
      _groups.removeAt(gi);
      await _persist();
    });
  }

  /// 그룹 재정렬: groupId 를 beforeGroupId 앞에 이동 (null이면 맨 뒤)
  Future<void> reorderGroup(int groupId, {int? insertBeforeGroupId}) async {
    await load();
    await _runLocked(() async {
      final fromIdx = _indexOfGroupId(groupId);
      final item = _groups.removeAt(fromIdx);
      final toIdx = _calcInsertIndexByBeforeGroupId(insertBeforeGroupId);
      _groups.insert(toIdx, item);
      await _persist();
    });
  }

  /// ====== 자산 관련 ======

  /// 자산 추가 (해당 그룹 내 맨 뒤 또는 beforeAssetId 앞에)
  Future<int> addAsset(
    int groupId, {
    required String name,
    required bool tracking,
    required int amount,
    String memo = '',
    int? insertBeforeAssetId,
  }) async {
    await load();
    final a = Asset(id: _genId(), name: name, tracking: tracking, amount: amount, memo: memo);

    await _runLocked(() async {
      final gi = _indexOfGroupId(groupId);
      final target = _groups[gi];
      final insertIdx = _calcInsertIndexByBeforeId(target, insertBeforeAssetId);
      target.assets.insert(insertIdx, a);
      await _persist();
    });

    return a.id;
  }

  /// 자산 수정 (부분 수정 가능)
  Future<void> updateAsset(
    int assetId, {
    String? name,
    bool? tracking,
    int? amount,
    String? memo,
  }) async {
    await load();
    await _runLocked(() async {
      final (gi, ai) = _locateAssetById(assetId);
      final a = _groups[gi].assets[ai];
      if (name != null) a.name = name;
      if (tracking != null) a.tracking = tracking;
      if (amount != null) a.amount = amount;
      if (memo != null) a.memo = memo;
      await _persist();
    });
  }

  /// 자산 삭제
  Future<void> deleteAsset(int assetId) async {
    await load();
    await _runLocked(() async {
      final (gi, ai) = _locateAssetById(assetId);
      _groups[gi].assets.removeAt(ai);
      await _persist();
    });
  }

  /// 자산 이동: assetId 를 toGroupId로 옮기며, insertBeforeAssetId 앞에 배치 (null이면 맨 뒤)
  Future<void> moveAsset({
    required int assetId,
    required int toGroupId,
    int? insertBeforeAssetId,
  }) async {
    await load();
    await _runLocked(() async {
      // 원래 위치에서 꺼내기
      final (fromGi, fromAi) = _locateAssetById(assetId);
      final item = _groups[fromGi].assets.removeAt(fromAi);

      // 대상 그룹에 삽입
      final toGi = _indexOfGroupId(toGroupId);
      final target = _groups[toGi];
      final insertIdx = _calcInsertIndexByBeforeId(target, insertBeforeAssetId);
      target.assets.insert(insertIdx, item);

      await _persist();
    });
  }

  /// ===== 유틸 =====

  /// 연속 호출을 직렬화(간단한 mutex)
  Future<void> _runLocked(Future<void> Function() action) async {
    final next = _mutex.then((_) => action());
    _mutex = next.catchError((_) {}); // 오류가 있어도 체인 유지
    await next;
  }
}
