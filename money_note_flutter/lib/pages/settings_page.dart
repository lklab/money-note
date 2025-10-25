import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_note/data/backup_manager.dart';
import 'package:money_note/data/budget_storage.dart';
import 'package:money_note/data/record_storage.dart';
import 'package:money_note/utils/style.dart';
import 'package:money_note/utils/utils.dart';
import 'package:money_note/widgets/labeled_input.dart';
import 'package:money_note/widgets/wands_button.dart';

class SettingsPage extends StatefulWidget {
  final int index;
  final ValueListenable<int> indexListenable;

  const SettingsPage({
    super.key,
    required this.index,
    required this.indexListenable,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _lastIndex;
  late final VoidCallback _listener;

  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _keyCtrl;

  late final FocusNode _hostFocus;
  late final FocusNode _portFocus;
  late final FocusNode _keyFocus;

  @override
  void initState() {
    super.initState();

    _lastIndex = widget.indexListenable.value;
    _listener = () {
      final now = widget.indexListenable.value;
      if (now == widget.index && _lastIndex != now) {
        _onPageShow();
      }
      if (_lastIndex == widget.index && now != widget.index) {
        _onPageHide();
      }
      _lastIndex = now;
    };
    widget.indexListenable.addListener(_listener);

    _hostCtrl = TextEditingController(text: BackupManager().host ?? '');
    _portCtrl = TextEditingController(text: BackupManager().port?.toString() ?? '');
    _keyCtrl = TextEditingController(text: '');

    _hostFocus = FocusNode();
    _portFocus = FocusNode();
    _keyFocus = FocusNode();
  }

  @override
  void dispose() {
    widget.indexListenable.removeListener(_listener);

    _hostCtrl.dispose();
    _portCtrl.dispose();
    _keyCtrl.dispose();
    _hostFocus.dispose();
    _portFocus.dispose();
    _keyFocus.dispose();

    super.dispose();
  }

  void _onPageShow() { }
  void _onPageHide() { }

  void _updatePage() {
    setState(() {
      _hostCtrl.text = BackupManager().host ?? '';
      _portCtrl.text = BackupManager().port?.toString() ?? '';
      _keyCtrl.text = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Container(
              color: Colors.transparent,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '백업',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            LabeledInput(
                              label: '주소',
                              child: TextField(
                                controller: _hostCtrl,
                                focusNode: _hostFocus,
                                textInputAction: TextInputAction.done,
                                decoration: Style.getSingleLineInputDecoration('주소를 입력하세요'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            LabeledInput(
                              label: '포트',
                              child: TextField(
                                controller: _portCtrl,
                                focusNode: _portFocus,
                                textInputAction: TextInputAction.done,
                                decoration: Style.getSingleLineInputDecoration('포트를 입력하세요'),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                            ),
                            const SizedBox(height: 16),
                            LabeledInput(
                              label: '키',
                              child: TextField(
                                controller: _keyCtrl,
                                focusNode: _keyFocus,
                                textInputAction: TextInputAction.done,
                                obscureText: true,
                                enableSuggestions: false,
                                autocorrect: false,
                                keyboardType: TextInputType.visiblePassword,
                                decoration: Style.getSingleLineInputDecoration('키를 입력하세요'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: WandsButton(
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();

                                  final host = _hostCtrl.text;
                                  final port = int.tryParse(_portCtrl.text); 
                                  final key = _keyCtrl.text;

                                  await BackupManager().setConfig(host: host, port: port, key: key);

                                  _updatePage();
                                },
                                text: '서버 설정 저장',
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: WandsButton(
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();

                                  final ok = await Utils.showConfirmPopup(context, '서버로부터 내역을 로드하시겠습니까?');
                                  if (ok != true) return;

                                  BackupData? backupData;

                                  try {
                                    backupData = await BackupManager().fetchBackupData();
                                  } catch (e) {
                                    if (context.mounted) {
                                      Utils.showPopup(context, '통신 실패', '서버와 통신하는 데에 실패했습니다.\n${e.toString()}}');
                                    }
                                    return;
                                  }

                                  if (backupData.records.isNotEmpty || backupData.monthlyBudgets.isNotEmpty) {
                                    if (backupData.records.isNotEmpty) {
                                      await RecordStorage().addRecords(backupData.records);
                                    }
                                    if (backupData.monthlyBudgets.isNotEmpty) {
                                      await BudgetStorage().importMonthlyBudgetsMerged(backupData.monthlyBudgets);
                                    }
                                    if (context.mounted) {
                                      Utils.showPopup(context, '완료', '내역 로드를 완료했습니다.');
                                    }
                                  } else {
                                    if (context.mounted) {
                                      Utils.showPopup(context, '완료', '로드된 내역이 없습니다.');
                                    }
                                  }
                                },
                                text: '내역 로드',
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: WandsButton(
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();

                                  try {
                                    await BackupManager().refreshApiKey();
                                  } catch (e) {
                                    if (context.mounted) {
                                      Utils.showPopup(context, '실패', '키를 업데이트하는 데에 실패했습니다.\n${e.toString()}}');
                                    }
                                    return;
                                  }

                                  if (context.mounted) {
                                    Utils.showSnack(context, '키를 업데이트했습니다.');
                                  }
                                },
                                text: '키 업데이트',
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: WandsButton(
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();

                                  final ok = await Utils.confirmDelete(context);
                                  if (ok != true) return;

                                  await BackupManager().deleteConfig();
                                },
                                text: '서버 정보 지우기',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
