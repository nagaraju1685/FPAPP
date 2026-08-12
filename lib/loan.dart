class FlexPayment {
  final num amount;
  final String date;

  FlexPayment({required this.amount, required this.date});

  factory FlexPayment.fromJson(Map<String, dynamic> json) {
    return FlexPayment(amount: json['amount'] as num, date: json['date'] as String);
  }

  Map<String, dynamic> toJson() => {'amount': amount, 'date': date};
}

class Loan {
  final String id;
  final String type; // 'EMI' or 'FLEX'
  final String currency;
  final String name;
  final num amount;
  final num balance;
  final String createdAt;

  // EMI-specific
  final num? monthlyEMI;
  final int? months;
  final String? startDate; // "YYYY-MM"
  final List<bool>? paidMonths;
  final int? emiDay; // day of month EMI is due, 1-31

  // FLEX-specific
  final String? expiryDate; // "YYYY-MM-DD"
  final List<FlexPayment>? payments;
  final num? minPaymentPercent;

  Loan({
    required this.id,
    required this.type,
    required this.currency,
    required this.name,
    required this.amount,
    required this.balance,
    required this.createdAt,
    this.monthlyEMI,
    this.months,
    this.startDate,
    this.paidMonths,
    this.emiDay,
    this.expiryDate,
    this.payments,
    this.minPaymentPercent,
  });

  bool get isEmi => type == 'EMI';

  int get paidMonthCount => paidMonths?.where((p) => p).length ?? 0;

  num get paidAmount => isEmi ? amount - balance : (payments?.fold<num>(0, (sum, p) => sum + p.amount) ?? 0);

  double get percentPaid => amount == 0 ? 0 : (paidAmount / amount).clamp(0, 1).toDouble();

  Loan copyWith({num? balance, List<bool>? paidMonths, List<FlexPayment>? payments}) {
    return Loan(
      id: id,
      type: type,
      currency: currency,
      name: name,
      amount: amount,
      balance: balance ?? this.balance,
      createdAt: createdAt,
      monthlyEMI: monthlyEMI,
      months: months,
      startDate: startDate,
      paidMonths: paidMonths ?? this.paidMonths,
      emiDay: emiDay,
      expiryDate: expiryDate,
      payments: payments ?? this.payments,
      minPaymentPercent: minPaymentPercent,
    );
  }

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'] as String,
      type: json['type'] as String,
      currency: json['currency'] as String,
      name: json['name'] as String,
      amount: json['amount'] as num,
      balance: json['balance'] as num,
      createdAt: json['createdAt'] as String,
      monthlyEMI: json['monthlyEMI'] as num?,
      months: json['months'] as int?,
      startDate: json['startDate'] as String?,
      paidMonths: (json['paidMonths'] as List?)?.map((e) => e as bool).toList(),
      emiDay: json['emiDay'] as int?,
      expiryDate: json['expiryDate'] as String?,
      payments: (json['payments'] as List?)
          ?.map((e) => FlexPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
      minPaymentPercent: json['minPaymentPercent'] as num?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'currency': currency,
      'name': name,
      'amount': amount,
      'balance': balance,
      'createdAt': createdAt,
      if (isEmi) ...{
        'monthlyEMI': monthlyEMI,
        'months': months,
        'startDate': startDate,
        'paidMonths': paidMonths,
        'emiDay': emiDay,
      } else ...{
        if (expiryDate != null) 'expiryDate': expiryDate,
        'payments': payments?.map((p) => p.toJson()).toList() ?? [],
      },
    };
  }
}
