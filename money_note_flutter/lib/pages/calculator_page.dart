import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_note_flutter/utils/style.dart';

class CalculatorPage extends StatefulWidget {
  /// 초기 숫자값(선택). 존재하면 입력식에 미리 채워집니다.
  final int? initialValue;

  const CalculatorPage({super.key, this.initialValue});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  /// 토큰: 숫자는 "123"처럼 문자열, 연산자는 "+ - * / ( )"
  final List<String> _tokens = [];
  final _nf = NumberFormat.decimalPattern();

  // 64비트 signed 정수 최대값
  static final BigInt _maxI64 = BigInt.parse('9223372036854775807');
  static const double _kBtnH = 56;

  bool _withinI64(String digits) {
    // 빈 문자열이나 숫자 아님은 여기까지 안 옴. 선행 0 허용.
    try {
      final v = BigInt.parse(digits);
      return v <= _maxI64;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue != 0) {
      if (widget.initialValue! > 0) {
        _tokens.add(widget.initialValue!.toString());
      } else {
        _tokens.add('-');
        _tokens.add((-widget.initialValue!).toString());
      }
    }
  }

  bool get _endsWithOperator =>
      _tokens.isNotEmpty && _isOperator(_tokens.last);

  int _openParenCount() =>
      _tokens.where((t) => t == '(').length - _tokens.where((t) => t == ')').length;

  bool _isOperator(String t) => t == '+' || t == '-' || t == '×' || t == '÷';

  bool _isDigit(String s) => s.codeUnits.every((c) => c >= 48 && c <= 57);

  String _formattedExpr() {
    if (_tokens.isEmpty) {
      return '0';
    }

    final b = StringBuffer();
    for (var i = 0; i < _tokens.length; i++) {
      final t = _tokens[i];
      if (_isDigit(t)) {
        b.write(_nf.format(int.parse(t)));
      } else {
        b.write(' $t ');
      }
    }
    return b.toString().trim();
  }

  void _pressDigit(String d) {
    setState(() {
      if (_tokens.isEmpty || (!_isDigit(_tokens.last) && _tokens.last != ')')) {
        // 새 숫자 시작: 한 자리 숫자는 항상 안전
        _tokens.add(d);
      } else if (_isDigit(_tokens.last)) {
        // 기존 숫자에 이어붙이기 → 64비트 한계 체크
        final next = _tokens.last + d;
        if (_withinI64(next)) {
          _tokens[_tokens.length - 1] = next;
        } else {
          // 초과 시 입력 무시 (원하면 스낵바 등 알림 추가 가능)
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('64비트 정수 최대값을 초과할 수 없어요.')),
          // );
        }
      } else if (_tokens.last == ')') {
        // 닫는 괄호 뒤에 새 숫자 시작
        _tokens.add(d);
      }
    });
  }

  void _pressOperator(String op) {
    setState(() {
      if (_tokens.isEmpty) {
        if (op == '×' || op == '÷') {
          return;
        }
      }
      else {
        if (_endsWithOperator) return; // 연속 연산자 금지
        if (_tokens.last == '(') return; // 여는 괄호 뒤 연산자 금지
      }
      _tokens.add(op);
    });
  }

  void _pressParenSmart() {
    setState(() {
      final hasLast = _tokens.isNotEmpty;
      final last = hasLast ? _tokens.last : null;
      final lastIsDigit = hasLast && _isDigit(last!);

      if (lastIsDigit) {
        // 1) 마지막이 숫자면 무조건 닫는 괄호 시도
        // 2) 단, 열린 괄호가 남아있지 않으면 입력 안 함
        if (_openParenCount() > 0) {
          _tokens.add(')');
        }
        // else: 무시
      } else {
        // 마지막 문자가 없거나 숫자가 아니면 무조건 여는 괄호
        _tokens.add('(');
      }
    });
  }

  void _pressBackspace() {
    setState(() {
      if (_tokens.isEmpty) return;
      final last = _tokens.last;
      if (_isDigit(last) && last.length > 1) {
        _tokens[_tokens.length - 1] = last.substring(0, last.length - 1);
      } else {
        _tokens.removeLast();
      }
    });
  }

  void _pressClearAll() {
    setState(() {
      _tokens.clear();
    });
  }

  /// 미리보기 계산(규칙 11, 12 적용)
  int? _previewResult() {
    if (_tokens.isEmpty) {
      return 0;
    }

    final tmp = <String>[];
    tmp.addAll(_tokens);

    // 규칙 12: 끝이 연산자면 무시
    if (tmp.isNotEmpty && _isOperator(tmp.last)) {
      tmp.removeLast();
    }
    // 규칙 10 보조: 닫는괄호 과잉이면 제거
    int balance = 0;
    final cleaned = <String>[];
    for (final t in tmp) {
      if (t == '(') {
        balance++;
        cleaned.add(t);
      } else if (t == ')') {
        if (balance > 0) {
          balance--;
          cleaned.add(t);
        } // else: 무시
      } else {
        cleaned.add(t);
      }
    }
    // 규칙 11: 남은 열린 괄호 닫기
    while (balance-- > 0) {
      cleaned.add(')');
    }

    if (cleaned.isNotEmpty && (cleaned.first == '+' || cleaned.first == '-')) {
      cleaned.insert(0, '0');
    }

    if (cleaned.isEmpty) return null;
    try {
      return _evalInfix(cleaned);
    } catch (_) {
      return null; // 계산 불가 시 결과 숨김
    }
  }

  /// 중위표기식을 정수 계산 (정수 나눗셈 ~/ 사용)
  int _evalInfix(List<String> toks) {
    // Shunting-yard → RPN
    final out = <String>[];
    final ops = <String>[];
    int prec(String op) => (op == '+' || op == '-') ? 1 : 2;

    for (final t in toks) {
      if (_isDigit(t)) {
        out.add(t);
      } else if (_isOperator(t)) {
        while (ops.isNotEmpty &&
            _isOperator(ops.last) &&
            prec(ops.last) >= prec(t)) {
          out.add(ops.removeLast());
        }
        ops.add(t);
      } else if (t == '(') {
        ops.add(t);
      } else if (t == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          out.add(ops.removeLast());
        }
        if (ops.isNotEmpty && ops.last == '(') ops.removeLast();
      }
    }
    while (ops.isNotEmpty) {
      out.add(ops.removeLast());
    }

    // Evaluate RPN
    final st = <int>[];
    for (final t in out) {
      if (_isDigit(t)) {
        st.add(int.parse(t));
      } else {
        if (st.length < 2) throw StateError('Bad expression');
        final b = st.removeLast();
        final a = st.removeLast();
        switch (t) {
          case '+':
            st.add(a + b);
            break;
          case '-':
            st.add(a - b);
            break;
          case '×':
            st.add(a * b);
            break;
          case '÷':
            if (b == 0) throw StateError('Division by zero');
            st.add(a ~/ b);
            break;
        }
      }
    }
    if (st.length != 1) throw StateError('Bad expression');
    return st.single;
  }

  void _pressConfirm() {
    final res = _previewResult();
    if (res != null) {
      Navigator.pop<int>(context, res);
    }
  }

  Widget _buildKey(String label, {VoidCallback? onTap, bool isAccent = false}) {
    return SizedBox(
      height: _kBtnH,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: FilledButton(
          onPressed: onTap,
          style: Style.buttonStyle.copyWith(
            backgroundColor: WidgetStatePropertyAll(
              isAccent ?
                Theme.of(context).colorScheme.secondaryContainer :
                Theme.of(context).colorScheme.primaryContainer
            )
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 20,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _previewResult();
    final expr = _formattedExpr();
    final resultLine = (result == null) ? '= ' : '= ${_nf.format(result)}';

    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: SafeArea(
        child: Column(
          children: [
            // 텍스트 영역: 남는 공간을 가득 채우고, 내용은 하단 정렬
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      expr.isEmpty ? ' ' : expr,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      resultLine,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 22,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 버튼 영역: 내부 버튼 고정크기에 맞춰 필요한 만큼만 세로 차지
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(child: _buildKey('C', onTap: _pressClearAll, isAccent: true)),
                    Expanded(child: _buildKey('()', onTap: _pressParenSmart, isAccent: true)),
                    Expanded(child: _buildKey('⌫', onTap: _pressBackspace, isAccent: true)),
                    Expanded(child: _buildKey('÷', onTap: () => _pressOperator('÷'), isAccent: true)),
                  ]),
                  Row(children: [
                    Expanded(child: _buildKey('7', onTap: () => _pressDigit('7'))),
                    Expanded(child: _buildKey('8', onTap: () => _pressDigit('8'))),
                    Expanded(child: _buildKey('9', onTap: () => _pressDigit('9'))),
                    Expanded(child: _buildKey('×', onTap: () => _pressOperator('×'), isAccent: true)),
                  ]),
                  Row(children: [
                    Expanded(child: _buildKey('4', onTap: () => _pressDigit('4'))),
                    Expanded(child: _buildKey('5', onTap: () => _pressDigit('5'))),
                    Expanded(child: _buildKey('6', onTap: () => _pressDigit('6'))),
                    Expanded(child: _buildKey('-', onTap: () => _pressOperator('-'), isAccent: true)),
                  ]),
                  Row(children: [
                    Expanded(child: _buildKey('1', onTap: () => _pressDigit('1'))),
                    Expanded(child: _buildKey('2', onTap: () => _pressDigit('2'))),
                    Expanded(child: _buildKey('3', onTap: () => _pressDigit('3'))),
                    Expanded(child: _buildKey('+', onTap: () => _pressOperator('+'), isAccent: true)),
                  ]),
                  Row(children: [
                    const Expanded(child: SizedBox.shrink()),
                    Expanded(child: _buildKey('0', onTap: () => _pressDigit('0'))),
                    const Expanded(child: SizedBox.shrink()),
                    Expanded(child: _buildKey('확인', onTap: _pressConfirm, isAccent: true)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
