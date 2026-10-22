import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/business_model.dart';
import '../../models/transaction_model.dart';
import '../../services/database_service.dart';
import 'home_screen.dart';
import 'reports_screen.dart';
import 'credit_score_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  List<TransactionModel> _transactions = [];
  BusinessModel _business = BusinessModel(
    id: 1,
    nombreNegocio: 'Bodega Doña Rosa',
    propietario: 'Rosa Quispe',
    rubro: 'Bodega y Abarrotes',
    codigoReferido: 'ROSA2026',
    puntosDifusion: 30,
    scoreCrediticio: 78,
  );

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final businessData = await DatabaseService.fetchBusiness();
    final txData = await DatabaseService.fetchTransactions();
    if (mounted) {
      setState(() {
        _business = businessData;
        _transactions = txData;
      });
    }
  }

  Future<void> _handleAddTransaction(TransactionModel newItem) async {
    setState(() {
      _transactions.insert(0, newItem);
    });
    await DatabaseService.saveTransaction(newItem);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        transactions: _transactions,
        onAddTransaction: _handleAddTransaction,
      ),
      ReportsScreen(transactions: _transactions),
      CreditScoreScreen(
        business: _business,
        transactionCount: _transactions.length,
      ),
      ProfileScreen(business: _business),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppTheme.darkGreen,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${_business.propietario}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                Text(
                  _business.nombreNegocio,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _selectedIndex = 3),
            icon: const Icon(
              Icons.settings_outlined,
              color: AppTheme.darkGreen,
            ),
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(
              Icons.account_balance_wallet_rounded,
              color: AppTheme.darkGreen,
            ),
            label: 'Caja',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(
              Icons.bar_chart_rounded,
              color: AppTheme.darkGreen,
            ),
            label: 'Flujo',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_user_outlined),
            selectedIcon: Icon(
              Icons.verified_user_rounded,
              color: AppTheme.darkGreen,
            ),
            label: 'Crédito',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: AppTheme.darkGreen,
            ),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
