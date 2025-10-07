import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:money_note_flutter/data/asset_storage.dart';

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

  bool _tracking = true;
  int _selectedGroupId = 0;
  int _amount = 0;

  late UnmodifiableListView<AssetGroup> _groups;

  bool get _isEdit => widget.asset != null;

  @override
  void initState() {
    super.initState();

    _groups = AssetStorage.instance.groups;

    final asset = widget.asset;
    _tracking = asset?.tracking ?? true;
    _selectedGroupId = _groups[0].id;
    _amount = asset?.amount ?? 0;

    _nameCtrl = TextEditingController(text: asset?.name ?? '');
    _memoCtrl = TextEditingController(text: asset?.memo ?? '');
    _amountCtrl = TextEditingController(text: _formatAmount(_amount));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String _formatAmount(int v) {
    // 간단한 천단위 구분 (필요 없으면 그냥 v.toString())
    final s = v.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write(',');
        count = 0;
      }
    }
    return buf.toString().split('').reversed.join();
  }

  ButtonStyle get _roundedBtnStyle => ButtonStyle(
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  Future<void> _onConfirmAdd() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('이름을 입력하세요');
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
      _showSnack('이름을 입력하세요');
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
    final ok = await _confirmDelete(context);
    if (ok != true) return;

    final asset = widget.asset!;
    await AssetStorage.instance.deleteAsset(asset.id);

    if (mounted) Navigator.of(context).pop(true);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickAmount() async {
    final result = await _showAmountDialog(context, initial: _amount);
    if (result == null) return;
    setState(() {
      _amount = result;
      _amountCtrl.text = _formatAmount(_amount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _isEdit;

    return Scaffold(
      appBar: AppBar(
        title: isEdit ? const Text('자산 수정') : const Text('자산 추가'),
      ),
      // 키보드가 올라와도 내용 스크롤 가능
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 1. 이름
              _RowLabelField(
                label: '이름',
                child: TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: '이름을 입력하세요',
                    isDense: true,
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(),
                    focusedBorder: UnderlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. 추적 체크박스
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 56,
                    child: Text(
                      '추적',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Checkbox(
                        value: _tracking,
                        onChanged: (v) => setState(() => _tracking = v ?? true),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. 자산그룹 드롭다운
              if (!_isEdit)
              _RowLabelField(
                label: '자산그룹',
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedGroupId,
                  items: _groups
                      .map((g) =>
                          DropdownMenuItem(value: g.id, child: Text(g.name)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    if (v != null) {
                      _selectedGroupId = v;
                    }
                  }),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(),
                    focusedBorder: UnderlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. 금액 (밑줄 TextField와 동일한 디자인, 버튼 동작)
              _RowLabelField(
                label: '금액',
                child: TextField(
                  controller: _amountCtrl,
                  readOnly: true,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(),
                    focusedBorder: UnderlineInputBorder(),
                  ),
                  onTap: _pickAmount,
                ),
              ),
              const SizedBox(height: 16),

              // 5. 메모 (여러 줄)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 56,
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        '메모',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _memoCtrl,
                      keyboardType: TextInputType.multiline,
                      minLines: 3,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: '메모를 입력하세요',
                        alignLabelWithHint: true,
                        border: UnderlineInputBorder(),
                        enabledBorder: UnderlineInputBorder(),
                        focusedBorder: UnderlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              // const Spacer(),

              if (!_isEdit)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _onConfirmAdd,
                    style: _roundedBtnStyle,
                    child: const Text('확인'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _onDelete,
                        style: _roundedBtnStyle,
                        child: const Text('삭제'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _onConfirmUpdate,
                        style: _roundedBtnStyle,
                        child: const Text('수정'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),

      // 6. 하단 버튼 (7. 둥근 모서리)
      // bottomNavigationBar: SafeArea(
      //   top: false,
      //   minimum: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      //   child: _isEdit
      //       ? Row(
      //           children: [
      //             Expanded(
      //               child: OutlinedButton(
      //                 onPressed: _onDelete,
      //                 style: _roundedBtnStyle,
      //                 child: const Text('삭제'),
      //               ),
      //             ),
      //             const SizedBox(width: 12),
      //             Expanded(
      //               child: FilledButton(
      //                 onPressed: _onConfirmUpdate,
      //                 style: _roundedBtnStyle,
      //                 child: const Text('수정'),
      //               ),
      //             ),
      //           ],
      //         )
      //       : SizedBox(
      //           width: double.infinity,
      //           child: FilledButton(
      //             onPressed: _onConfirmAdd,
      //             style: _roundedBtnStyle,
      //             child: const Text('확인'),
      //           ),
      //         ),
      // ),
    );
  }
}

/// 공통: 좌측 고정 폭 라벨 + 우측 확장 입력 위젯
class _RowLabelField extends StatelessWidget {
  final String label;
  final Widget child;
  const _RowLabelField({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('삭제하시겠어요?'),
      content: const Text('이 작업은 되돌릴 수 없습니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
}

/// 금액 입력 다이얼로그 (정수만)
Future<int?> _showAmountDialog(BuildContext context, {required int initial}) {
  final ctrl = TextEditingController(text: initial.toString());
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('금액 입력'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '정수 금액',
            border: UnderlineInputBorder(),
            enabledBorder: UnderlineInputBorder(),
            focusedBorder: UnderlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final raw = ctrl.text.trim();
              final parsed = int.tryParse(raw.replaceAll(',', ''));
              if (parsed == null) {
                Navigator.of(ctx).pop(); // 그냥 닫음 (원하면 에러 처리 가능)
              } else {
                Navigator.of(ctx).pop(parsed);
              }
            },
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
}
