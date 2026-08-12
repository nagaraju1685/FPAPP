import 'package:flutter/material.dart';

import 'loan.dart';

Future<Loan?> showAddLoanDialog(BuildContext context, {required String currency}) {
  return showDialog<Loan>(
    context: context,
    builder: (_) => AddLoanDialog(currency: currency),
  );
}

class AddLoanDialog extends StatefulWidget {
  final String currency;

  const AddLoanDialog({super.key, required this.currency});

  @override
  State<AddLoanDialog> createState() => _AddLoanDialogState();
}

class _AddLoanDialogState extends State<AddLoanDialog> {
  static const _primaryBlue = Color(0xFF2A3EDB);

  final _formKey = GlobalKey<FormState>();
  String _loanType = 'EMI';

  final _nameController = TextEditingController();

  // EMI fields
  final _monthlyEmiController = TextEditingController();
  final _monthsController = TextEditingController();
  DateTime _emiStartMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // Flex fields
  final _totalAmountController = TextEditingController();
  final _minPaymentPercentController = TextEditingController();
  DateTime? _expiryDate;

  @override
  void dispose() {
    _nameController.dispose();
    _monthlyEmiController.dispose();
    _monthsController.dispose();
    _totalAmountController.dispose();
    _minPaymentPercentController.dispose();
    super.dispose();
  }

  num get _emiTotal {
    final monthly = num.tryParse(_monthlyEmiController.text) ?? 0;
    final months = int.tryParse(_monthsController.text) ?? 0;
    return monthly * months;
  }

  Future<void> _pickEmiStartMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _emiStartMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'EMI start month',
    );
    if (picked != null) {
      setState(() => _emiStartMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Expiry / close-by date',
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(DateTime.now().hashCode & 0xFFFF).toRadixString(36)}';
    final createdAt = DateTime.now().toUtc().toIso8601String();

    if (_loanType == 'EMI') {
      final monthly = num.parse(_monthlyEmiController.text);
      final months = int.parse(_monthsController.text);
      final total = monthly * months;
      final loan = Loan(
        id: id,
        type: 'EMI',
        currency: widget.currency,
        name: _nameController.text.trim(),
        amount: total,
        balance: total,
        createdAt: createdAt,
        monthlyEMI: monthly,
        months: months,
        startDate: '${_emiStartMonth.year}-${_twoDigits(_emiStartMonth.month)}',
        paidMonths: List.filled(months, false),
      );
      Navigator.of(context).pop(loan);
    } else {
      final total = num.parse(_totalAmountController.text);
      final minPaymentPercent = num.tryParse(_minPaymentPercentController.text);
      final loan = Loan(
        id: id,
        type: 'FLEX',
        currency: widget.currency,
        name: _nameController.text.trim(),
        amount: total,
        balance: total,
        createdAt: createdAt,
        expiryDate: _expiryDate == null
            ? null
            : '${_expiryDate!.year}-${_twoDigits(_expiryDate!.month)}-${_twoDigits(_expiryDate!.day)}',
        payments: const [],
        minPaymentPercent: minPaymentPercent,
      );
      Navigator.of(context).pop(loan);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New Loan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                _TypeTabs(
                  selected: _loanType,
                  onChanged: (value) => setState(() => _loanType = value),
                ),
                const SizedBox(height: 20),
                _Label('Loan Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: _fieldDecoration(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                if (_loanType == 'EMI') ..._buildEmiFields() else ..._buildFlexFields(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Add Loan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEmiFields() {
    return [
      _Label('Monthly EMI Amount', suffix: '(${widget.currency})'),
      const SizedBox(height: 6),
      TextFormField(
        controller: _monthlyEmiController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _fieldDecoration(),
        onChanged: (_) => setState(() {}),
        validator: (v) => (num.tryParse(v ?? '') == null) ? 'Enter a valid amount' : null,
      ),
      const SizedBox(height: 16),
      _Label('Number of EMIs'),
      const SizedBox(height: 6),
      TextFormField(
        controller: _monthsController,
        keyboardType: TextInputType.number,
        decoration: _fieldDecoration(),
        onChanged: (_) => setState(() {}),
        validator: (v) => (int.tryParse(v ?? '') == null || int.parse(v!) <= 0) ? 'Enter a valid count' : null,
      ),
      const SizedBox(height: 16),
      _Label('EMI Start Month'),
      const SizedBox(height: 6),
      InkWell(
        onTap: _pickEmiStartMonth,
        child: InputDecorator(
          decoration: _fieldDecoration(),
          child: Text(
            '${_monthName(_emiStartMonth.month)} ${_emiStartMonth.year}',
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8ECFB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Total Loan Amount = ${widget.currency == 'INR' ? '₹' : 'S\$'}${_emiTotal.toStringAsFixed(2)}',
          style: const TextStyle(color: _primaryBlue, fontWeight: FontWeight.w700),
        ),
      ),
    ];
  }

  List<Widget> _buildFlexFields() {
    return [
      _Label('Total Amount', suffix: '(${widget.currency})'),
      const SizedBox(height: 6),
      TextFormField(
        controller: _totalAmountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _fieldDecoration(),
        validator: (v) => (num.tryParse(v ?? '') == null) ? 'Enter a valid amount' : null,
      ),
      const SizedBox(height: 16),
      _Label('Min. Payment %', suffix: '(optional, 0-20)'),
      const SizedBox(height: 6),
      TextFormField(
        controller: _minPaymentPercentController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _fieldDecoration(),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          final pct = num.tryParse(v);
          if (pct == null || pct < 0 || pct > 20) return 'Enter a value between 0 and 20';
          return null;
        },
      ),
      const SizedBox(height: 16),
      _Label('Expiry / Close-by Date', suffix: '(optional)'),
      const SizedBox(height: 6),
      InkWell(
        onTap: _pickExpiryDate,
        child: InputDecorator(
          decoration: _fieldDecoration(),
          child: Text(
            _expiryDate == null
                ? 'Select a date'
                : '${_twoDigits(_expiryDate!.month)}/${_twoDigits(_expiryDate!.day)}/${_expiryDate!.year}',
            style: TextStyle(fontSize: 15, color: _expiryDate == null ? Colors.grey.shade500 : Colors.black87),
          ),
        ),
      ),
    ];
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF3F4F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month - 1];
  }
}

class _TypeTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TypeTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(label: '🗓️ EMI', selected: selected == 'EMI', onTap: () => onChanged('EMI')),
          ),
          Expanded(
            child: _TabButton(
              label: '🎯 Flexible',
              selected: selected == 'FLEX',
              onTap: () => onChanged('FLEX'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF2A3EDB) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final String? suffix;

  const _Label(this.text, {this.suffix});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
        children: [
          TextSpan(text: text),
          if (suffix != null)
            TextSpan(
              text: '  $suffix',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }
}
