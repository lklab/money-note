import 'package:flutter/material.dart';
import 'package:money_note_flutter/data/asset_storage.dart';

class AssetGroupEditPage extends StatefulWidget {
  final AssetGroup? assetGroup;

  const AssetGroupEditPage({
    super.key,
    this.assetGroup,
  });

  @override
  State<AssetGroupEditPage> createState() => _AssetGroupEditPageState();
}

class _AssetGroupEditPageState extends State<AssetGroupEditPage> {
  late final TextEditingController _nameCtrl;

  bool get _isEdit => widget.assetGroup != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.assetGroup?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
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

    await AssetStorage.instance.addGroup(name);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onConfirmUpdate() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('이름을 입력하세요');
      return;
    }

    final group = widget.assetGroup!;
    await AssetStorage.instance.renameGroup(group.id, name);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onDelete() async {
    final ok = await _confirmDelete(context);
    if (ok != true) return;

    final group = widget.assetGroup!;
    await AssetStorage.instance.deleteGroupIfEmpty(group.id);

    if (mounted) Navigator.of(context).pop(true);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isEdit ? const Text('자산그룹 수정') : const Text('자산그룹 추가'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 1~3. 라벨 + 밑줄 TextField
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 56, // 고정 가로길이
                    child: Text(
                      '이름',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: '이름을 입력하세요',
                        isDense: true,
                        border: UnderlineInputBorder(),
                        enabledBorder: UnderlineInputBorder(),
                        focusedBorder: UnderlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        if (_isEdit) {
                          _onConfirmUpdate();
                        } else {
                          _onConfirmAdd();
                        }
                      },
                    ),
                  ),
                ],
              ),

              // 4. 중간 공간 비우기
              const SizedBox(height: 12),
              const Spacer(),

              // 5~7. 하단 버튼들
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
