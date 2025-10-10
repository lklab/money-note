import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_note_flutter/data/asset_storage.dart';
import 'package:money_note_flutter/data/backup_manager.dart';
import 'package:money_note_flutter/data/budget_storage.dart';
import 'package:money_note_flutter/data/record_storage.dart';
import 'package:money_note_flutter/pages/main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initStroages();

  runApp(
    ProviderScope(
      child: MainApp(),
    ),
  );
  }

Future _initStroages() async {
  final assetStorage = AssetStorage.instance;
  await assetStorage.load();

  if (assetStorage.groups.isEmpty) {
    await assetStorage.addGroup('새 그룹');
  }

  await RecordStorage().init();
  await BudgetStorage().init();

  await BackupManager().init();
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({
    super.key,
  });

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Note',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        brightness: Brightness.light,
        fontFamily: 'NotoSansKR',
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/main',
      routes: {
        '/main': (BuildContext _) => const MainPage(),
      },
    );
  }
}
