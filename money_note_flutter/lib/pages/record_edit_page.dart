import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_note_flutter/data/record_storage.dart';
import 'package:money_note_flutter/pages/calculator_page.dart';
import 'package:money_note_flutter/utils/style.dart';
import 'package:money_note_flutter/utils/utils.dart';
import 'package:money_note_flutter/widgets/labeled_input.dart';
import 'package:money_note_flutter/widgets/wands_button.dart';

class RecordEditPage extends StatefulWidget {
  final Record? record;
  final DateTime? initialDate;

  const RecordEditPage({
    super.key,
    this.record,
    this.initialDate,
  });

  @override
  State<RecordEditPage> createState() => _RecordEditPageState();
}

class _RecordEditPageState extends State<RecordEditPage> {
  late final TextEditingController _dateCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _memoCtrl;

  late final FocusNode _contentFocus;
  late final FocusNode _memoFocus;

  DateTime _date = DateTime.now();
  RecordKind _kind = RecordKind.expense;
  String _selectedBudget = 'none';
  int _amount = 0;

  @override
  void initState() {
    super.initState();

    final record = widget.record;

    if (record != null) {
      _date = record.dateTime;
    } else if (widget.initialDate != null) {
      _date = widget.initialDate!;
    }

    _kind = record?.kind ?? RecordKind.expense;
    _selectedBudget = record?.budget ?? 'none';
    _amount = record?.amount ?? 0;

    _dateCtrl = TextEditingController(text: _formatDate(_date));
    _contentCtrl = TextEditingController(text: record?.content ?? '');
    _memoCtrl = TextEditingController(text: record?.memo ?? '');
    _amountCtrl = TextEditingController(text: Utils.formatMoney(_amount));

    _contentFocus = FocusNode();
    _memoFocus = FocusNode();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _contentCtrl.dispose();
    _memoCtrl.dispose();
    _amountCtrl.dispose();

    _contentFocus.dispose();
    _memoFocus.dispose();

    super.dispose();
  }

  Future<void> _onConfirmAdd() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      Utils.showSnack(context, '내용을 입력하세요');
      return;
    }

    await RecordStorage().addRecord(
      dateTime: _date,
      kind: _kind,
      budget: _selectedBudget,
      amount: _amount,
      content: content,
      memo: _memoCtrl.text,
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onConfirmUpdate() async {
    final record = widget.record!;
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      Utils.showSnack(context, '내용을 입력하세요');
      return;
    }

    await RecordStorage().updateRecord(
      record.id,
      dateTime: _date,
      kind: _kind,
      budget: _selectedBudget,
      amount: _amount,
      content: content,
      memo: _memoCtrl.text,
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onDelete() async {
    final ok = await Utils.confirmDelete(context);
    if (ok != true) return;

    final record = widget.record!;
    await RecordStorage().deleteRecord(record.id);

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

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    bool isEdit = widget.record != null;
    List<String> budgetNames = ['없음', '내 예산'];
    List<String> budgetIds = ['none', 'mybudget'];

    if (widget.record != null && !budgetIds.contains(widget.record!.budget)) {
      _selectedBudget = budgetIds[0];
    }

    return Scaffold(
      appBar: AppBar(
        title: isEdit ? const Text('내역 수정') : const Text('내역 추가'),
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
                              label: '날짜',
                              child: TextField(
                                controller: _dateCtrl,
                                readOnly: true,
                                showCursor: false,
                                enableInteractiveSelection: false,
                                decoration: Style.inputDecoration,
                                onTap: () async {
                                  final newDate = await Utils.pickDateTime(context, initial: _date);

                                  if (newDate != null) {
                                    setState(() {
                                      _date = newDate;
                                      _dateCtrl.text = _formatDate(_date);
                                    });
                                  }
                                },
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
                                        if (_kind == RecordKind.income) {
                                          return;
                                        }
                                        setState(() {
                                          _kind = RecordKind.income;
                                        });
                                      },
                                      isFilled: _kind == RecordKind.income,
                                      text: '수입',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: WandsButton(
                                      onPressed: () {
                                        if (_kind == RecordKind.expense) {
                                          return;
                                        }
                                        setState(() {
                                          _kind = RecordKind.expense;
                                        });
                                      },
                                      isFilled: _kind == RecordKind.expense,
                                      text: '지출',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            LabeledInput(
                              label: '예산',
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedBudget,
                                items: List.generate(budgetNames.length, (i) {
                                  return DropdownMenuItem(value: budgetIds[i], child: Text(budgetNames[i]),);
                                }),
                                onChanged: (v) => setState(() {
                                  if (v != null) {
                                    _selectedBudget = v;
                                  }
                                }),
                                decoration: Style.inputDecoration,
                              ),
                            ),
                            const SizedBox(height: 16),

                            LabeledInput(
                              label: '내용',
                              child: TextField(
                                controller: _contentCtrl,
                                focusNode: _contentFocus,
                                textInputAction: TextInputAction.done,
                                decoration: Style.getSingleLineInputDecoration('내용을 입력하세요'),
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
