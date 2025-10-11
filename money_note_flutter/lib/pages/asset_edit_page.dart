import 'package:flutter/material.dart';
import 'package:money_note/data/asset_storage.dart';
import 'package:money_note/pages/calculator_page.dart';
import 'package:money_note/utils/style.dart';
import 'package:money_note/utils/utils.dart';
import 'package:money_note/widgets/labeled_input.dart';

class AssetEditPage extends StatefulWidget {
  final Asset? asset;

  const AssetEditPage({
    super.key,
    this.asset,
  });

  @override
  State<AssetEditPage> createState() => _AssetEditPageState();
}

class _AssetEditPageState extends State<AssetEditPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _memoCtrl;

  late final FocusNode _nameFocus;
  late final FocusNode _memoFocus;

  bool _tracking = true;
  int _selectedGroupId = 0;
  int _amount = 0;

  bool get _isEdit => widget.asset != null;

  @override
  void initState() {
    super.initState();

    final groups = AssetStorage.instance.groups;

    final asset = widget.asset;
    _tracking = asset?.tracking ?? true;
    _selectedGroupId = groups[0].id;
    _amount = asset?.amount ?? 0;

    _nameCtrl = TextEditingController(text: asset?.name ?? '');
    _memoCtrl = TextEditingController(text: asset?.memo ?? '');
    _amountCtrl = TextEditingController(text: Utils.formatMoney(_amount));

    _nameFocus = FocusNode();
    _memoFocus = FocusNode();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    _amountCtrl.dispose();
    _nameFocus.dispose();
    _memoFocus.dispose();
    super.dispose();
  }

  Future<void> _onConfirmAdd() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Utils.showSnack(context, '이름을 입력하세요');
      return;
    }

    await AssetStorage.instance.addAsset(
      _selectedGroupId,
      name: name,
      tracking: _tracking,
      amount: _amount,
      memo: _memoCtrl.text,
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onConfirmUpdate() async {
    final asset = widget.asset!;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Utils.showSnack(context, '이름을 입력하세요');
      return;
    }

    await AssetStorage.instance.updateAsset(
      asset.id,
      name: name,
      tracking: _tracking,
      amount: _amount,
      memo: _memoCtrl.text,
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onDelete() async {
    final ok = await Utils.confirmDelete(context);
    if (ok != true) return;

    final asset = widget.asset!;
    await AssetStorage.instance.deleteAsset(asset.id);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pickAmount() async {
    FocusScope.of(context).unfocus();

    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CalculatorPage(initialValue: _amount),
      ),
    );

    if (result == null) return;

    setState(() {
      _amount = result;
      _amountCtrl.text = Utils.formatMoney(_amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = AssetStorage.instance.groups;
    final isEdit = _isEdit;

    return Scaffold(
      appBar: AppBar(
        title: isEdit ? const Text('자산 수정') : const Text('자산 추가'),
      ),
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
                          children: [
                            LabeledInput(
                              label: '이름',
                              child: TextField(
                                controller: _nameCtrl,
                                focusNode: _nameFocus,
                                textInputAction: TextInputAction.done,
                                decoration: Style.getSingleLineInputDecoration('이름을 입력하세요'),
                              ),
                            ),
                            const SizedBox(height: 16),
                      
                            LabeledInput(
                              label: '추적',
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Checkbox(
                                  value: _tracking,
                                  onChanged: (v) {
                                    FocusScope.of(context).unfocus();
                                    setState(() => _tracking = v ?? true);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                      
                            if (!_isEdit)
                            LabeledInput(
                              label: '그룹',
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedGroupId,
                                items: groups
                                    .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  if (v != null) {
                                    _selectedGroupId = v;
                                  }
                                }),
                                decoration: Style.inputDecoration,
                              ),
                            ),
                            const SizedBox(height: 16),
                      
                            LabeledInput(
                              label: '금액',
                              child: TextField(
                                controller: _amountCtrl,
                                readOnly: true,
                                showCursor: false,
                                enableInteractiveSelection: false,
                                decoration: Style.inputDecoration,
                                onTap: _pickAmount,
                              ),
                            ),
                            const SizedBox(height: 16),
                      
                            LabeledInput(
                              label: '메모',
                              crossAxisAlignment: CrossAxisAlignment.start,
                              child: TextField(
                                controller: _memoCtrl,
                                focusNode: _memoFocus,
                                keyboardType: TextInputType.multiline,
                                minLines: 3,
                                maxLines: null,
                                textInputAction: TextInputAction.done,
                                decoration: Style.getMultiLineInputDecoration('메모를 입력하세요'),
                              ),
                            ),
                      
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                
                    if (!_isEdit)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _onConfirmAdd,
                        style: Style.buttonStyle,
                        child: const Text('확인'),
                      ),
                    ),
                
                    if (_isEdit)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _onDelete,
                            style: Style.buttonStyle,
                            child: const Text('삭제'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _onConfirmUpdate,
                            style: Style.buttonStyle,
                            child: const Text('수정'),
                          ),
                        ),
                      ],
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
