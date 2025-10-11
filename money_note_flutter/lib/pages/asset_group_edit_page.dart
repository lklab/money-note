import 'package:flutter/material.dart';
import 'package:money_note/data/asset_storage.dart';
import 'package:money_note/utils/style.dart';
import 'package:money_note/utils/utils.dart';
import 'package:money_note/widgets/labeled_input.dart';

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
  final FocusNode _focusNode = FocusNode();

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

  Future<void> _onConfirmAdd() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Utils.showSnack(context, '이름을 입력하세요');
      return;
    }

    await AssetStorage.instance.addGroup(name);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onConfirmUpdate() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Utils.showSnack(context, '이름을 입력하세요');
      return;
    }

    final group = widget.assetGroup!;
    await AssetStorage.instance.renameGroup(group.id, name);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onDelete() async {
    final groups = AssetStorage.instance.groups;
    final group = widget.assetGroup!;

    if (groups.length <= 1) {
      Utils.showSnack(context, '자산그룹은 최소 1개 이상 있어야 합니다');
      return;
    }

    if (group.assets.isNotEmpty) {
      Utils.showSnack(context, '자산이 없는 자산그룹만 삭제할 수 있습니다');
      return;
    }

    final ok = await Utils.confirmDelete(context);
    if (ok != true) return;

    await AssetStorage.instance.deleteGroupIfEmpty(group.id);

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isEdit ? const Text('자산그룹 수정') : const Text('자산그룹 추가'),
      ),
      body: GestureDetector(
        onTap: () {
          if (_focusNode.hasFocus) {
            _focusNode.unfocus();
          }
        },
        child: Stack(
          children: [
            Container(
              color: Colors.transparent,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    LabeledInput(
                      label: '이름',
                      child: TextField(
                        controller: _nameCtrl,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.done,
                        decoration: Style.getSingleLineInputDecoration('이름을 입력하세요'),
                        onSubmitted: (_) {
                          if (_isEdit) {
                            _onConfirmUpdate();
                          } else {
                            _onConfirmAdd();
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Spacer(),

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
