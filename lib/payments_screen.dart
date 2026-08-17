import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'loan.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  static const _primaryBlue = Color(0xFF2A3EDB);
  static const _darkNavy = Color(0xFF13205C);
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  List<Loan> _loans = [];
  bool _loading = true;
  String? _error;
  late DateTime _selectedMonth;
  String _selectedCurrency = 'INR';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loans = await ApiClient.getLoans();
      if (!mounted) return;
      setState(() => _loans = loans);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load loans. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    final now = DateTime.now();
    if (next.year > now.year || (next.year == now.year && next.month > now.month)) return;
    setState(() => _selectedMonth = next);
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    int year = _selectedMonth.year;
    int month = _selectedMonth.month;
    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final maxMonth = year == now.year ? now.month : 12;
            return AlertDialog(
              title: const Text('Select month'),
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: month,
                    items: List.generate(maxMonth, (i) => i + 1)
                        .map((m) => DropdownMenuItem(value: m, child: Text(_months[m - 1])))
                        .toList(),
                    onChanged: (v) => setDialogState(() => month = v ?? month),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: year,
                    items: List.generate(6, (i) => now.year - 5 + i)
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) => setDialogState(() {
                      year = v ?? year;
                      if (year == now.year && month > now.month) month = now.month;
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(DateTime(year, month)),
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) setState(() => _selectedMonth = result);
  }

  // Index of the EMI loan's month-schedule that corresponds to the selected month, or null if inactive.
  int? _monthIndexFor(Loan loan) {
    final startDate = loan.startDate;
    final months = loan.months;
    if (startDate == null || months == null) return null;
    final parts = startDate.split('-');
    final startYear = int.tryParse(parts[0]);
    final startMonth = int.tryParse(parts[1]);
    if (startYear == null || startMonth == null) return null;
    final index = (_selectedMonth.year - startYear) * 12 + (_selectedMonth.month - startMonth);
    if (index < 0 || index >= months) return null;
    return index;
  }

  List<_MonthlyEmiEntry> get _monthlyEmiLoans {
    final entries = <_MonthlyEmiEntry>[];
    for (final loan in _loans.where((l) => l.isEmi && l.currency == _selectedCurrency)) {
      final index = _monthIndexFor(loan);
      if (index == null) continue;
      entries.add(_MonthlyEmiEntry(loan: loan, monthIndex: index));
    }
    entries.sort((a, b) => (a.loan.emiDay ?? 1).compareTo(b.loan.emiDay ?? 1));
    return entries;
  }

  Future<void> _toggleMonthPaid(Loan loan, int index) async {
    final paidMonths = List<bool>.from(loan.paidMonths!);
    paidMonths[index] = !paidMonths[index];
    final paidCount = paidMonths.where((p) => p).length;
    final newBalance = loan.amount - (paidCount * (loan.monthlyEMI ?? 0));
    final updatedLoan = loan.copyWith(paidMonths: paidMonths, balance: newBalance);

    final previous = _loans;
    final updated = _loans.map((l) => l.id == loan.id ? updatedLoan : l).toList();
    setState(() => _loans = updated);
    try {
      await ApiClient.saveLoans(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loans = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loans = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save changes. Please try again.')),
      );
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  List<Loan> get _flexLoans => _loans
      .where((l) =>
          !l.isEmi &&
          l.currency == _selectedCurrency &&
          (l.minPaymentPercent ?? 0) > 0 &&
          (l.balance > 0 || _paidInMonth(l, _selectedMonth)))
      .toList();

  static const _monthAbbrs = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  // Payment dates are usually ISO 8601, but some rows (added outside the app)
  // store a display string like "Aug 17, 2026" instead.
  DateTime? _parsePaymentDate(String raw) {
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    final match = RegExp(r'^([A-Za-z]{3,})\s+(\d{1,2}),\s*(\d{4})$').firstMatch(raw.trim());
    if (match == null) return null;
    final monthIndex = _monthAbbrs.indexOf(match.group(1)!.toLowerCase().substring(0, 3));
    if (monthIndex == -1) return null;
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || year == null) return null;
    return DateTime(year, monthIndex + 1, day);
  }

  bool _paidInMonth(Loan loan, DateTime month) {
    return (loan.payments ?? []).any((p) {
      final date = _parsePaymentDate(p.date);
      if (date == null) return false;
      return date.year == month.year && date.month == month.month;
    });
  }

  num _minPaymentAmount(Loan loan) {
    return ((loan.balance * (loan.minPaymentPercent ?? 0) / 100) * 100).round() / 100;
  }

  num _paidAmountInMonth(Loan loan, DateTime month) {
    return (loan.payments ?? []).fold<num>(0, (sum, p) {
      final date = _parsePaymentDate(p.date);
      if (date == null || date.year != month.year || date.month != month.month) return sum;
      return sum + p.amount;
    });
  }

  Future<void> _payFlexMin(Loan loan) async {
    final minAmount = _minPaymentAmount(loan);
    if (minAmount <= 0) return;

    final payments = [
      ...?loan.payments,
      FlexPayment(amount: minAmount, date: DateTime.now().toUtc().toIso8601String()),
    ];
    final newBalance = (loan.balance - minAmount).clamp(0, loan.amount);
    final updatedLoan = loan.copyWith(payments: payments, balance: newBalance);

    final previous = _loans;
    final updated = _loans.map((l) => l.id == loan.id ? updatedLoan : l).toList();
    setState(() => _loans = updated);
    try {
      await ApiClient.saveLoans(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loans = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loans = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save changes. Please try again.')),
      );
    }
  }

  String _currencySymbol(String currency) => currency == 'INR' ? '₹' : 'S\$';

  String _formatAmount(num value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final grouped = parts[0].length <= 3
        ? parts[0]
        : parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return '$grouped.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final entries = _monthlyEmiLoans;
    final totalAmount = entries.fold<num>(0, (sum, e) => sum + (e.loan.monthlyEMI ?? 0));
    final paidAmount = entries
        .where((e) => (e.loan.paidMonths?[e.monthIndex] ?? false))
        .fold<num>(0, (sum, e) => sum + (e.loan.monthlyEMI ?? 0));
    final remainingAmount = totalAmount - paidAmount;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildMonthSelector(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadLoans,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null) ...[
                              _ErrorBanner(message: _error!, onRetry: _loadLoans),
                              const SizedBox(height: 16),
                            ],
                            if (entries.isNotEmpty) ...[
                              _buildPieChartCard(totalAmount, paidAmount, remainingAmount),
                              const SizedBox(height: 16),
                            ],
                            _buildEmiListCard(entries),
                            if (_flexLoans.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildFlexListCard(_flexLoans),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left, color: _darkNavy, size: 28),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          const Text('💳', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text(
            'Payments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _darkNavy),
          ),
          const Spacer(),
          _CurrencyToggle(
            selected: _selectedCurrency,
            onChanged: (value) => setState(() => _selectedCurrency = value),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => _shiftMonth(-1),
            icon: const Icon(Icons.chevron_left, color: _primaryBlue),
          ),
          InkWell(
            onTap: _pickMonth,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                '${_months[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _darkNavy),
              ),
            ),
          ),
          IconButton(
            onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
            icon: const Icon(Icons.chevron_right, color: _primaryBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(num total, num paid, num remaining) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS MONTH — TOTAL EMI',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(
                  painter: _PieChartPainter(paid: paid.toDouble(), remaining: remaining.toDouble()),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: ${_formatAmount(total)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 12),
                    _LegendDot(color: const Color(0xFF4ADE80), label: 'Paid: ${_formatAmount(paid)}'),
                    const SizedBox(height: 8),
                    _LegendDot(color: const Color(0xFFDC2626), label: 'Remaining: ${_formatAmount(remaining)}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmiListCard(List<_MonthlyEmiEntry> entries) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EMI LOANS — ${_months[_selectedMonth.month - 1].toUpperCase()} ${_selectedMonth.year}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No EMI loans due this month.', style: TextStyle(color: Colors.grey.shade500)),
              ),
            )
          else ...[
            Table(
              columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1)},
              children: [
                TableRow(children: [
                  _TableHeader('LOAN NAME'),
                  _TableHeader('EMI AMOUNT'),
                  _TableHeader('PAID'),
                ]),
                for (final entry in entries)
                  TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(entry.loan.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (entry.loan.emiDay != null)
                            Text(
                              'EMI day ${entry.loan.emiDay}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        '${_currencySymbol(entry.loan.currency)}${_formatAmount(entry.loan.monthlyEMI ?? 0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Checkbox(
                        value: entry.loan.paidMonths?[entry.monthIndex] ?? false,
                        activeColor: const Color(0xFF16A34A),
                        onChanged: _isCurrentMonth
                            ? (_) => _toggleMonthPaid(entry.loan, entry.monthIndex)
                            : null,
                      ),
                    ),
                  ]),
              ],
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildFlexListCard(List<Loan> flexLoans) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FLEXI EMI — MINIMUM PAYMENT',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          for (final loan in flexLoans) ...[
            _buildFlexRow(loan),
            if (loan != flexLoans.last) const Divider(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildFlexRow(Loan loan) {
    final minAmount = _minPaymentAmount(loan);
    final paid = _paidInMonth(loan, _selectedMonth);
    final disabled = paid || minAmount <= 0 || !_isCurrentMonth;
    final displayAmount = paid ? _paidAmountInMonth(loan, _selectedMonth) : minAmount;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loan.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                paid
                    ? 'Paid this month'
                    : 'Min. payment: ${loan.minPaymentPercent}% of balance',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${_currencySymbol(loan.currency)}${_formatAmount(displayAmount)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ElevatedButton(
          onPressed: disabled ? null : () => _payFlexMin(loan),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            disabledBackgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(paid ? 'Paid' : 'Pay'),
        ),
      ],
    );
  }
}

class _MonthlyEmiEntry {
  final Loan loan;
  final int monthIndex;

  _MonthlyEmiEntry({required this.loan, required this.monthIndex});
}

class _PieChartPainter extends CustomPainter {
  final double paid;
  final double remaining;

  _PieChartPainter({required this.paid, required this.remaining});

  @override
  void paint(Canvas canvas, Size size) {
    final total = paid + remaining;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (total <= 0) {
      final paint = Paint()..color = const Color(0xFFE0E3EE);
      canvas.drawArc(rect, 0, 2 * math.pi, true, paint);
      return;
    }

    final paidSweep = 2 * math.pi * (paid / total);
    final paidPaint = Paint()..color = const Color(0xFF4ADE80);
    final remainingPaint = Paint()..color = const Color(0xFFDC2626);

    canvas.drawArc(rect, -math.pi / 2, paidSweep, true, paidPaint);
    canvas.drawArc(rect, -math.pi / 2 + paidSweep, 2 * math.pi - paidSweep, true, remainingPaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.paid != paid || oldDelegate.remaining != remaining;
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
      ),
    );
  }
}

class _CurrencyToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CurrencyToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(label: '₹ INR', selected: selected == 'INR', onTap: () => onChanged('INR')),
          _ToggleChip(label: 'S\$ SGD', selected: selected == 'SGD', onTap: () => onChanged('SGD')),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF2A3EDB) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
      ],
    );
  }
}
