import 'package:flutter/material.dart';

import 'add_loan_dialog.dart';
import 'api_client.dart';
import 'loan.dart';

class LoansScreen extends StatefulWidget {
  final String username;

  const LoansScreen({super.key, required this.username});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  static const _primaryBlue = Color(0xFF2A3EDB);
  static const _darkNavy = Color(0xFF13205C);

  String _selectedCurrency = 'INR';
  List<Loan> _loans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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

  Future<void> _persist(List<Loan> updated) async {
    final previous = _loans;
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

  Future<void> _handleAddLoan() async {
    final loan = await showAddLoanDialog(context, currency: _selectedCurrency);
    if (loan == null) return;
    await _persist([..._loans, loan]);
  }

  Future<void> _toggleMonthPaid(Loan loan, int index) async {
    final paidMonths = List<bool>.from(loan.paidMonths!);
    paidMonths[index] = !paidMonths[index];
    final paidCount = paidMonths.where((p) => p).length;
    final newBalance = loan.amount - (paidCount * (loan.monthlyEMI ?? 0));
    final updatedLoan = loan.copyWith(paidMonths: paidMonths, balance: newBalance);
    await _persist(_loans.map((l) => l.id == loan.id ? updatedLoan : l).toList());
  }

  Future<void> _deleteLoan(Loan loan) async {
    await _persist(_loans.where((l) => l.id != loan.id).toList());
  }

  Future<void> _addFlexPayment(Loan loan) async {
    final controller = TextEditingController();
    final amount = await showDialog<num>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Payment'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Payment amount'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(num.tryParse(controller.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;

    final payments = [...?loan.payments, FlexPayment(amount: amount, date: DateTime.now().toUtc().toIso8601String())];
    final newBalance = (loan.balance - amount).clamp(0, loan.amount);
    final updatedLoan = loan.copyWith(payments: payments, balance: newBalance);
    await _persist(_loans.map((l) => l.id == loan.id ? updatedLoan : l).toList());
  }

  List<Loan> get _visibleLoans => _loans.where((l) => l.currency == _selectedCurrency).toList();

  String get _currencySymbol => _selectedCurrency == 'INR' ? '₹' : 'S\$';

  String _groupThousands(String digits) {
    if (digits.length <= 3) return digits;
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  @override
  Widget build(BuildContext context) {
    final currencyLoans = _visibleLoans;
    final loanCount = currencyLoans.length;
    final totalDebt = currencyLoans.fold<num>(0, (sum, l) => sum + l.amount);
    final paid = currencyLoans.fold<num>(0, (sum, l) => sum + l.paidAmount);
    final remaining = currencyLoans.fold<num>(0, (sum, l) => sum + l.balance);

    final inrLoans = _loans.where((l) => l.currency == 'INR').toList();
    final sgdLoans = _loans.where((l) => l.currency == 'SGD').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildSummaryBar(inrLoans, sgdLoans),
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
                            _buildOverviewCard(loanCount, totalDebt, paid, remaining),
                            const SizedBox(height: 16),
                            if (currencyLoans.any((l) => l.type == 'FLEX' && l.expiryDate != null))
                              _buildFlexiPriorityCard(currencyLoans),
                            const SizedBox(height: 16),
                            ...currencyLoans.map((loan) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: loan.isEmi ? _buildEmiCard(loan) : _buildFlexCard(loan),
                                )),
                            if (currencyLoans.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                    'No loans yet. Tap "+ Add Loan" to get started.',
                                    style: TextStyle(color: Colors.grey.shade500),
                                  ),
                                ),
                              ),
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
          const Text('💰', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text(
            'FP',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _darkNavy,
            ),
          ),
          const SizedBox(width: 16),
          _CurrencyToggle(
            selected: _selectedCurrency,
            onChanged: (value) => setState(() => _selectedCurrency = value),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _handleAddLoan,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Loan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(List<Loan> inrLoans, List<Loan> sgdLoans) {
    num sumRemaining(List<Loan> loans) => loans.fold<num>(0, (s, l) => s + l.balance);

    return Container(
      color: _darkNavy,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        children: [
          _CurrencyStatsRow(
            currencyLabel: '₹ INR',
            loans: inrLoans.length,
            remaining: '₹${_formatAmountFor(sumRemaining(inrLoans))}',
          ),
          const SizedBox(height: 14),
          _CurrencyStatsRow(
            currencyLabel: 'S\$ SGD',
            loans: sgdLoans.length,
            remaining: 'S\$${_formatAmountFor(sumRemaining(sgdLoans))}',
          ),
        ],
      ),
    );
  }

  String _formatAmountFor(num value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    return '${_groupThousands(parts[0])}.${parts[1]}';
  }

  Widget _buildOverviewCard(int loanCount, num totalDebt, num paid, num remaining) {
    final percentPaid = totalDebt == 0 ? 0.0 : (paid / totalDebt).clamp(0, 1).toDouble();
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
            'OVERVIEW — $_selectedCurrency',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: loanCount == 0 ? 1 : percentPaid,
                      strokeWidth: 22,
                      backgroundColor: const Color(0xFFFACC77).withValues(alpha: 0.35),
                      valueColor: AlwaysStoppedAnimation(
                        loanCount == 0 ? const Color(0xFFE0E3EE) : const Color(0xFF4ADE80),
                      ),
                    ),
                  ),
                  Text(
                    loanCount == 0 ? 'No loans yet' : '${(percentPaid * 100).toStringAsFixed(0)}% paid',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Colors.greenAccent.shade400, label: 'Paid'),
              const SizedBox(width: 20),
              _LegendDot(color: Colors.redAccent.shade200, label: 'Remaining'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlexiPriorityCard(List<Loan> loans) {
    final flexLoans = loans
        .where((l) => l.type == 'FLEX' && l.expiryDate != null && l.balance > 0)
        .toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));

    if (flexLoans.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 0),
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
          Row(
            children: [
              const Text('⏰', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text('Flexi Loans — Close Priority', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sorted by expiry date — address the earliest first',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2)},
            children: [
              TableRow(children: [
                _TableHeader('LOAN'),
                _TableHeader('REMAINING'),
                _TableHeader('EXPIRES ON'),
              ]),
              for (final loan in flexLoans)
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(loan.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '$_currencySymbol${_formatAmountFor(loan.balance)}',
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_formatDate(loan.expiryDate!)),
                  ),
                ]),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    return '${months[month - 1]} $day, ${parts[0]}';
  }

  Widget _buildEmiCard(Loan loan) {
    final months = loan.months ?? 0;
    final paidCount = loan.paidMonthCount;
    final percent = months == 0 ? 0.0 : paidCount / months;

    return _LoanCardShell(
      onDelete: () => _deleteLoan(loan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Badge(label: 'EMI', color: Color(0xFF2A3EDB)),
              const SizedBox(width: 8),
              _Badge(label: loan.currency, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${loan.name} ($months)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Stat2(value: '$_currencySymbol${_formatAmountFor(loan.amount)}', label: 'TOTAL')),
              Expanded(
                child: _Stat2(
                  value: '$_currencySymbol${_formatAmountFor(loan.monthlyEMI ?? 0)}',
                  label: 'MONTHLY EMI',
                  valueColor: _primaryBlue,
                ),
              ),
              Expanded(
                child: _Stat2(
                  value: '$_currencySymbol${_formatAmountFor(loan.paidAmount)}',
                  label: 'PAID',
                  valueColor: const Color(0xFF16A34A),
                ),
              ),
              Expanded(
                child: _Stat2(
                  value: '$_currencySymbol${_formatAmountFor(loan.balance)}',
                  label: 'REMAINING',
                  valueColor: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: const Color(0xFFE0E3EE),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADE80)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$paidCount / $months months paid · ${(percent * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          _PaymentSchedule(loan: loan, onToggle: (i) => _toggleMonthPaid(loan, i)),
        ],
      ),
    );
  }

  Widget _buildFlexCard(Loan loan) {
    final percent = loan.percentPaid;
    final expiry = loan.expiryDate;
    int? daysLeft;
    if (expiry != null) {
      final parts = expiry.split('-').map(int.parse).toList();
      final expiryDt = DateTime(parts[0], parts[1], parts[2]);
      daysLeft = expiryDt.difference(DateTime.now()).inDays;
    }

    return _LoanCardShell(
      onDelete: () => _deleteLoan(loan),
      trailing: TextButton.icon(
        onPressed: () => _addFlexPayment(loan),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Payment'),
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFE8ECFB),
          foregroundColor: _primaryBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Badge(label: 'FLEXIBLE', color: Color(0xFF2A3EDB)),
              const SizedBox(width: 8),
              _Badge(label: loan.currency, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(loan.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (expiry != null)
            Text(
              '📅 ${_formatDate(expiry)}${daysLeft != null ? ' · ${daysLeft}d left' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Stat2(value: '$_currencySymbol${_formatAmountFor(loan.amount)}', label: 'TOTAL LOAN')),
              Expanded(
                child: _Stat2(
                  value: '$_currencySymbol${_formatAmountFor(loan.paidAmount)}',
                  label: 'PAID',
                  valueColor: const Color(0xFF16A34A),
                ),
              ),
              Expanded(
                child: _Stat2(
                  value: '$_currencySymbol${_formatAmountFor(loan.balance)}',
                  label: 'REMAINING',
                  valueColor: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: const Color(0xFFE0E3EE),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADE80)),
            ),
          ),
          const SizedBox(height: 6),
          Text('${(percent * 100).toStringAsFixed(1)}% paid', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Text('PAYMENT HISTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          if (loan.payments == null || loan.payments!.isEmpty)
            Text('No payments recorded yet', style: TextStyle(fontSize: 13, color: Colors.grey.shade400))
          else
            ...loan.payments!.reversed.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$_currencySymbol${_formatAmountFor(p.amount)} · ${_formatDate(p.date.substring(0, 10))}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
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

class _LoanCardShell extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;
  final Widget? trailing;

  const _LoanCardShell({required this.child, required this.onDelete, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade400),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSchedule extends StatefulWidget {
  final Loan loan;
  final ValueChanged<int> onToggle;

  const _PaymentSchedule({required this.loan, required this.onToggle});

  @override
  State<_PaymentSchedule> createState() => _PaymentScheduleState();
}

class _PaymentScheduleState extends State<_PaymentSchedule> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final paidMonths = widget.loan.paidMonths ?? const [];
    final startDate = widget.loan.startDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'PAYMENT SCHEDULE — CLICK MONTH TO TOGGLE PAID',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.3),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: Colors.grey.shade500),
              Text(_expanded ? 'HIDE' : 'SHOW', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(paidMonths.length, (i) {
                final label = _monthLabel(startDate, i);
                final paid = paidMonths[i];
                return InkWell(
                  onTap: () => widget.onToggle(i),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: paid ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: paid ? const Color(0xFF4ADE80) : Colors.grey.shade300),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: paid ? const Color(0xFF16A34A) : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  String _monthLabel(String? startDate, int index) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (startDate == null) return 'M${index + 1}';
    final parts = startDate.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? 1;
    final total = (month - 1) + index;
    final targetYear = year + total ~/ 12;
    final targetMonth = total % 12;
    return '${months[targetMonth]} $targetYear';
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

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _Stat2 extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _Stat2({required this.value, required this.label, this.valueColor = Colors.black87});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 9, letterSpacing: 0.3)),
      ],
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

class _CurrencyStatsRow extends StatelessWidget {
  final String currencyLabel;
  final int loans;
  final String remaining;

  const _CurrencyStatsRow({
    required this.currencyLabel,
    required this.loans,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CurrencyBadge(currencyLabel),
        const SizedBox(width: 20),
        _Stat(value: '$loans', label: 'LOANS'),
        const SizedBox(width: 40),
        _Stat(value: remaining, label: 'REMAINING', valueColor: const Color(0xFFFACC15)),
      ],
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  final String label;
  const _CurrencyBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _Stat({required this.value, required this.label, this.valueColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 0.5)),
      ],
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
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    );
  }
}
