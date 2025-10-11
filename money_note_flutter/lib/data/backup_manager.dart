import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:money_note/data/budget_storage.dart';
import 'package:money_note/data/record_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupData {
  final List<Record> records;
  final List<MonthlyBudget> monthlyBudgets;

  const BackupData({
    required this.records,
    required this.monthlyBudgets,
  });

  factory BackupData.empty() => const BackupData(records: [], monthlyBudgets: []);

  Map<String, dynamic> toJson() => {
        'records': records
            .map((r) => {
                  'id': r.id,
                  'dateTime': r.dateTime.toIso8601String(),
                  'kind': recordKindToInt(r.kind), // int
                  'budget': r.budget,
                  'amount': r.amount.toString(), // 서버 스펙: 문자열
                  'content': r.content,
                  'memo': r.memo,
                })
            .toList(),
        'monthlyBudgets': monthlyBudgets.map(_monthlyBudgetToJson).toList(),
      };

  static BackupData fromJson(Map<String, dynamic> json) {
    final recList = <Record>[];
    final list = (json['records'] as List<dynamic>? ?? <dynamic>[]);
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final amountStr = item['amount']?.toString() ?? '0';
        final amount = int.parse(amountStr);
        final kindInt =
            item['kind'] is int ? item['kind'] as int : int.parse(item['kind'].toString());
        recList.add(
          Record(
            id: item['id'] as String,
            dateTime: DateTime.parse(item['dateTime'] as String),
            kind: intToRecordKind(kindInt),
            budget: item['budget'] as String,
            amount: amount,
            content: item['content'] as String,
            memo: item['memo'] as String,
          ),
        );
    } }

    final mbJson = (json['monthlyBudgets'] as List<dynamic>? ?? <dynamic>[]);
    final mbs = mbJson
        .whereType<Map<String, dynamic>>()
        .map(_monthlyBudgetFromJson)
        .toList();

    return BackupData(records: recList, monthlyBudgets: mbs);
  }

  // ---- JSON helpers for MonthlyBudget/BudgetGroup/Budget ----

  static Map<String, dynamic> _monthlyBudgetToJson(MonthlyBudget mb) => {
        'monthKey': mb.monthKey,
        'groups': mb.groups.map(_budgetGroupToJson).toList(),
      };

  static Map<String, dynamic> _budgetGroupToJson(BudgetGroup g) => {
        'id': g.id,
        'name': g.name,
        'budgets': g.budgets.map(_budgetToJson).toList(),
      };

  static Map<String, dynamic> _budgetToJson(Budget b) => {
        'id': b.id,
        'name': b.name,
        'kind': budgetKindToInt(b.kind), // int
        'assetType': budgetAssetTypeToInt(b.assetType), // int
        'amount': b.amount.toString(), // 서버 스펙: 문자열
      };

  static MonthlyBudget _monthlyBudgetFromJson(Map<String, dynamic> m) {
    final groups = (m['groups'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_budgetGroupFromJson)
        .toList();

    return MonthlyBudget(
      monthKey: (m['monthKey'] as num).toInt(),
      groups: groups,
    );
  }

  static BudgetGroup _budgetGroupFromJson(Map<String, dynamic> g) {
    final budgets = (g['budgets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_budgetFromJson)
        .toList();

    return BudgetGroup(
      id: g['id'] as String,
      name: g['name'] as String,
      budgets: budgets,
    );
  }

  static Budget _budgetFromJson(Map<String, dynamic> b) {
    final amountStr = b['amount']?.toString() ?? '0';
    final kindInt = b['kind'] is int ? b['kind'] as int : int.parse(b['kind'].toString());
    final assetInt =
        b['assetType'] is int ? b['assetType'] as int : int.parse(b['assetType'].toString());

    return Budget(
      id: b['id'] as String,
      name: b['name'] as String,
      kind: intToBudgetKind(kindInt),
      assetType: intToBudgetAssetType(assetInt),
      amount: int.parse(amountStr),
    );
  }
}

class BackupManager {
  static const _prefHost = 'backup_host';
  static const _prefPort = 'backup_port';
  static const _prefKey  = 'backup_key';

  String? _host;
  int? _port;
  String? _key;

  final http.Client _client;

  String? get host => _host;
  int? get port => _port;

  static final BackupManager _instance = BackupManager._internal();
  factory BackupManager() => _instance;

  BackupManager._internal() : _client = http.Client();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_prefHost);
    _port = prefs.getInt(_prefPort);
    _key  = prefs.getString(_prefKey);
  }

  Future<void> setConfig({
    required String? host,
    required int? port,
    required String? key,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (host != null && host.isNotEmpty) {
      _host = host.trim();
      await prefs.setString(_prefHost, _host!);
    }

    if (port != null) {
      _port = port;
      await prefs.setInt(_prefPort, _port!);
    }

    if (key != null && key.isNotEmpty) {
      _key = key;
      await prefs.setString(_prefKey, _key!);
    }
  }

  /// 저장된 서버 설정을 제거하고(SharedPreferences) 메모리도 초기화한다.
  Future<void> deleteConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefHost);
    await prefs.remove(_prefPort);
    await prefs.remove(_prefKey);

    // 메모리 상태도 즉시 반영
    _host = null;
    _port = null;
    _key  = null;
  }

  Uri _uri(String path) {
    if (_host == null || _port == null) {
      throw StateError('BackupManager: 서버 설정이 없습니다. setConfig() 또는 init()을 호출하세요.');
    }
    return Uri(scheme: 'http', host: _host, port: _port, path: path);
  }

  Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'X-API-Key': _keyOrThrow,
  };

  String get _keyOrThrow {
    final k = _key;
    if (k == null || k.isEmpty) {
      throw StateError('BackupManager: 인증 키가 없습니다. setConfig() 또는 init()을 호출하세요.');
    }
    return k;
  }

  /// GET /records
  Future<List<Record>> fetchAllRecords() async {
    if (_host == null) {
      return [];
    }

    final resp = await _client.get(_uri('/records'), headers: _jsonHeaders);

    if (resp.statusCode != 200) {
      throw Exception('GET /records 실패: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (data['records'] as List<dynamic>? ?? <dynamic>[]);
    final result = <Record>[];

    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final amountStr = item['amount']?.toString() ?? '0';
        final amount = int.parse(amountStr);
        final kindInt = item['kind'] is int ? item['kind'] as int : int.parse(item['kind'].toString());

        result.add(
          Record(
            id: item['id'] as String,
            dateTime: DateTime.parse(item['dateTime'] as String),
            kind: intToRecordKind(kindInt),
            budget: item['budget'] as String,
            amount: amount,
            content: item['content'] as String,
            memo: item['memo'] as String,
          ),
        );
      }
    }
    return result;
  }

  /// POST /record (헤더에 키, 바디에서 key 제외)
  Future<void> uploadRecordsForMonth(DateTime monthHint, List<Record> records) async {
    if (_host == null) {
      return;
    }

    final yyyymm = monthHint.year * 100 + monthHint.month;

    final body = {
      'month': yyyymm,
      'records': records.map((r) => {
        'id'      : r.id,
        'dateTime': r.dateTime.toIso8601String(),
        'kind'    : recordKindToInt(r.kind),
        'budget'  : r.budget,
        'amount'  : r.amount.toString(), // 서버 스펙: 문자열
        'content' : r.content,
        'memo'    : r.memo,
      }).toList(),
    };

    final resp = await _client.post(
      _uri('/record'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw Exception('POST /record 실패: ${resp.statusCode} ${resp.body}');
    }
  }

  /// GET /backupdata
  Future<BackupData> fetchBackupData() async {
    if (_host == null) {
      return BackupData.empty();
    }

    final resp = await _client.get(_uri('/backupdata'), headers: _jsonHeaders);

    if (resp.statusCode != 200) {
      throw Exception('GET /backupdata 실패: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('GET /backupdata 응답 형식 오류: ${resp.body}');
    }
    return BackupData.fromJson(data);
  }

  /// POST /backupdata
  Future<void> uploadBackupDataForMonth(
    DateTime monthHint, {
    required List<Record> records,
    required List<MonthlyBudget> monthlyBudgets,
  }) async {
    if (_host == null) {
      return;
    }

    final yyyymm = monthHint.year * 100 + monthHint.month;

    final data = BackupData(
      records: records,
      monthlyBudgets:
          monthlyBudgets.where((mb) => mb.monthKey == yyyymm).toList(),
    );

    final body = {
      'month': yyyymm,
      ...data.toJson(),
    };

    final resp = await _client.post(
      _uri('/backupdata'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw Exception('POST /backupdata 실패: ${resp.statusCode} ${resp.body}');
    }
  }

  /// GET /refresh
  Future<String> refreshApiKey() async {
    _uri('/_ping');
    final currentKey = _keyOrThrow;

    final resp = await _client.get(
      _uri('/refresh'),
      headers: {
        'Accept': 'application/json',
        'X-API-Key': currentKey,
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('GET /refresh 실패: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    final newKey = (data is Map && data['key'] is String) ? data['key'] as String : null;
    if (newKey == null || newKey.isEmpty) {
      throw Exception('GET /refresh 응답에 key가 없습니다: ${resp.body}');
    }

    final prefs = await SharedPreferences.getInstance();
    _key = newKey;
    await prefs.setString(_prefKey, newKey);

    return newKey;
  }

  void dispose() {
    _client.close();
  }
}
