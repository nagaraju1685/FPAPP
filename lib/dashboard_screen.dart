import 'package:flutter/material.dart';

import 'api_client.dart';
import 'expense_screen.dart';
import 'loans_screen.dart';
import 'loan.dart';
import 'login_screen.dart';
import 'payments_screen.dart';
import 'profile_screen.dart';
import 'property_screen.dart';
import 'todo_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String username;

  const DashboardScreen({super.key, required this.username});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _primaryBlue = Color(0xFF2A3EDB);
  static const _darkNavy = Color(0xFF13205C);
  static const _bgColor = Color(0xFFF3F4F8);

  List<Loan> _loans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    setState(() => _loading = true);
    try {
      final loans = await ApiClient.getLoans();
      if (!mounted) return;
      setState(() => _loans = loans);
    } catch (_) {
      // Dashboard summary is best-effort; errors are surfaced on the Loans screen.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLogout() async {
    await ApiClient.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  List<Loan> get _upcomingFlexPayments {
    final flexLoans = _loans
        .where((l) => l.type == 'FLEX' && l.expiryDate != null && l.balance > 0)
        .toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
    return flexLoans;
  }

  String _currencySymbol(String currency) => currency == 'INR' ? '₹' : 'S\$';

  String _groupThousands(String digits) {
    if (digits.length <= 3) return digits;
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  String _formatAmount(num value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    return '${_groupThousands(parts[0])}.${parts[1]}';
  }

  String _formatDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    return '${months[month - 1]} $day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadLoans,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuickAccessHeader(),
                      const SizedBox(height: 14),
                      _buildQuickAccessGrid(),
                      const SizedBox(height: 28),
                      _buildUpcomingPaymentsHeader(),
                      const SizedBox(height: 14),
                      _buildUpcomingPaymentsList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_darkNavy, _primaryBlue],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💰', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Financial Planner',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'logout') _handleLogout();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Hello, ${widget.username} 👋',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Have a great day ahead!',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessHeader() {
    return const Text(
      'Quick Access',
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _darkNavy),
    );
  }

  Widget _buildQuickAccessGrid() {
    final tiles = [
      _QuickAccessItem(
        icon: Icons.person_outline,
        title: 'Profile',
        subtitle: 'View & edit profile',
        color: const Color(0xFF7C6FF0),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfileScreen(username: widget.username)),
        ),
      ),
      _QuickAccessItem(
        icon: Icons.account_balance_outlined,
        title: 'Loans',
        subtitle: 'View and manage Loans',
        color: const Color(0xFF2A3EDB),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoansScreen(username: widget.username)),
        ),
      ),
      _QuickAccessItem(
        icon: Icons.payments_outlined,
        title: 'Payments',
        subtitle: 'View Monthly Payments',
        color: const Color(0xFF16A34A),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaymentsScreen()),
        ),
      ),
      _QuickAccessItem(
        icon: Icons.home_work_outlined,
        title: 'Property',
        subtitle: 'View and Manage Properties',
        color: const Color(0xFFD97706),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PropertyScreen()),
        ),
      ),
      _QuickAccessItem(
        icon: Icons.receipt_long_outlined,
        title: 'Daily Expense',
        subtitle: 'View & add expenses',
        color: const Color(0xFFDB2777),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ExpenseScreen()),
        ),
      ),
      _QuickAccessItem(
        icon: Icons.checklist_outlined,
        title: 'Todo',
        subtitle: 'View & edit Todo list',
        color: const Color(0xFF0891B2),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TodoScreen()),
        ),
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.92,
      children: tiles,
    );
  }

  Widget _buildUpcomingPaymentsHeader() {
    return const Text(
      'Upcoming payments',
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _darkNavy),
    );
  }

  Widget _buildUpcomingPaymentsList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final flexLoans = _upcomingFlexPayments;
    if (flexLoans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Text(
          'No flexi payments due right now.',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return Column(
      children: [
        for (final loan in flexLoans)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _UpcomingPaymentCard(
              name: loan.name,
              amount: '${_currencySymbol(loan.currency)}${_formatAmount(loan.balance)}',
              date: _formatDate(loan.expiryDate!),
            ),
          ),
      ],
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: Colors.white),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingPaymentCard extends StatelessWidget {
  final String name;
  final String amount;
  final String date;

  const _UpcomingPaymentCard({required this.name, required this.amount, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEFF6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              date,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF13205C)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Flexi payment due', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              amount,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}
