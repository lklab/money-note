import 'package:flutter/material.dart';
import 'package:money_note_flutter/data/budget_storage.dart';
import 'package:money_note_flutter/pages/calculator_page.dart';
import 'package:money_note_flutter/utils/style.dart';
import 'package:money_note_flutter/utils/utils.dart';
import 'package:money_note_flutter/widgets/labeled_input.dart';
import 'package:money_note_flutter/widgets/wands_button.dart';

class BudgetEditPage extends StatefulWidget {
  final DateTime month;
  final List<BudgetGroup> groups;
  final Budget? budget;
  final BudgetGroup? group;

  const BudgetEditPage({
    super.key,
    required this.month,
    required this.groups,
    this.budget,
    this.group,
  });

  @override
  State<BudgetEditPage> createState() => _BudgetEditPageState();
}

class _BudgetEditPageState extends State<BudgetEditPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;

  late final FocusNode _nameFocus;

  BudgetKind _kind = BudgetKind.expense;
  BudgetAssetType _assetType = BudgetAssetType.cash;
  late BudgetGroup _selectedGroup;
  int _amount = 0;

  @override
  void initState() {
    super.initState();

    final budget = widget.budget;

    if (budget != null) {
      _kind = budget.kind;
      _assetType = budget.assetType;
      _selectedGroup = widget.group!;
      _amount = budget.amount;
    } else {
      _selectedGroup = widget.groups[0];
    }

    _nameCtrl = TextEditingController(text: budget?.name ?? '');
    _amountCtrl = TextEditingController(text: Utils.formatMoney(_amount));

    _nameFocus = FocusNode();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();

    _nameFocus.dispose();

    super.dispose();
  }

  Future<void> _onConfirmAdd() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Utils.showSnack(context, '이름을 입력하세요');
      return;
    }

    await BudgetStorage().addBudget(
      name: name,
      kind: _kind,
      assetType: _assetType,
      amount: _amount,
      groupId: _selectedGroup.id,
      month: widget.month,
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onConfirmUpdate() async {
    final budget = widget.budget!;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Utils.showSnack(context, '이름을 입력하세요');
      return;
    }

    await BudgetStorage().updateBudget(
      budget.id,
      name: name,
      kind: _kind,
      assetType: _assetType,
      amount: _amount,
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onDelete() async {
    final ok = await Utils.confirmDelete(context);
    if (ok != true) return;

    final budget = widget.budget!;
    final group = widget.group!;

    await BudgetStorage().deleteBudget(
      budgetId: budget.id,
      groupId: group.id,
      month: widget.month,
    );

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
    bool isEdit = widget.budget != null;

    return Scaffold(
      appBar: AppBar(
        title: isEdit ? const Text('예산 수정') : const Text('예산 추가'),
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
                                decoration: Style.getSingleLineInputDecoration('내용을 입력하세요'),
                              ),
                            ),
                            const SizedBox(height: 16),

                            LabeledInput(
                              label: '그룹',
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedGroup.id,
                                items: List.generate(widget.groups.length, (i) {
                                  return DropdownMenuItem(value: widget.groups[i].id, child: Text(widget.groups[i].name),);
                                }),
                                onChanged: (v) => setState(() {
                                  if (v != null) {
                                    for (BudgetGroup group in widget.groups) {
                                      if (group.id == v) {
                                        _selectedGroup = group;
                                        return;
                                      }
                                    }
                                    _selectedGroup = widget.groups[0];
                                  }
                                }),
                                decoration: Style.inputDecoration,
                              ),
                            ),
                            const SizedBox(height: 16),

                            LabeledInput(
                              label: '수지',
                              child: Row(
                                children: [
                                  Expanded(
                                    child: WandsButton(
                                      onPressed: () {
                                        if (_kind == BudgetKind.income) {
                                          return;
                                        }
                                        setState(() {
                                          _kind = BudgetKind.income;
                                        });
                                      },
                                      isFilled: _kind == BudgetKind.income,
                                      text: '수입',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: WandsButton(
                                      onPressed: () {
                                        if (_kind == BudgetKind.expense) {
                                          return;
                                        }
                                        setState(() {
                                          _kind = BudgetKind.expense;
                                        });
                                      },
                                      isFilled: _kind == BudgetKind.expense,
                                      text: '지출',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            LabeledInput(
                              label: '타입',
                              child: Row(
                                children: [
                                  Expanded(
                                    child: WandsButton(
                                      onPressed: () {
                                        if (_assetType == BudgetAssetType.cash) {
                                          return;
                                        }
                                        setState(() {
                                          _assetType = BudgetAssetType.cash;
                                        });
                                      },
                                      isFilled: _assetType == BudgetAssetType.cash,
                                      text: '현금',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: WandsButton(
                                      onPressed: () {
                                        if (_assetType == BudgetAssetType.capital) {
                                          return;
                                        }
                                        setState(() {
                                          _assetType = BudgetAssetType.capital;
                                        });
                                      },
                                      isFilled: _assetType == BudgetAssetType.capital,
                                      text: '자본',
                                    ),
                                  ),
                                ],
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
                          ],
                        ),
                      ),
                    ),

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
