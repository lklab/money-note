import 'package:flutter/material.dart';
import 'package:money_note_flutter/data/budget_storage.dart';
import 'package:money_note_flutter/utils/style.dart';
import 'package:money_note_flutter/utils/utils.dart';
import 'package:money_note_flutter/widgets/labeled_input.dart';

class BudgetGroupEditPage extends StatefulWidget {
  final DateTime month;
  final BudgetGroup? budgetGroup;

  const BudgetGroupEditPage({
    super.key,
    required this.month,
    this.budgetGroup,
  });

  @override
  State<BudgetGroupEditPage> createState() => _BudgetGroupEditPageState();
}

class _BudgetGroupEditPageState extends State<BudgetGroupEditPage> {
  late final TextEditingController _nameCtrl;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.budgetGroup?.name ?? '');
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

    await BudgetStorage().addBudgetGroup(
      name: name,
      month: widget.month,
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onConfirmUpdate() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Utils.showSnack(context, '이름을 입력하세요');
      return;
    }

    await BudgetStorage().updateBudgetGroupName(widget.budgetGroup!.id, name);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onDelete() async {
    final group = widget.budgetGroup!;

    final ok = await Utils.confirmDelete(context);
    if (ok != true) return;

    await BudgetStorage().deleteBudgetGroup(groupId: group.id, month: widget.month);

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    bool isEdit = widget.budgetGroup != null;

    return Scaffold(
      appBar: AppBar(
        title: isEdit ? const Text('예산그룹 수정') : const Text('예산그룹 추가'),
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
                          if (isEdit) {
                            _onConfirmUpdate();
                          } else {
                            _onConfirmAdd();
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Spacer(),

                    if (!isEdit)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _onConfirmAdd,
                        style: Style.buttonStyle,
                        child: const Text('확인'),
                      ),
                    ),

                    if (isEdit)
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
