import 'package:flutter/material.dart';
import '../ui/components/ff_design_system.dart';
import '../ui/theme/app_spacing.dart';
import 'pay_categories_screen.dart';
import 'receive_categories_screen.dart';
import 'bank_accounts_screen.dart';
import 'payment_methods_screen.dart';

/// Tela principal do menu "Tabelas" do FácilFin.
///
/// Exibe 4 opções de cadastro:
/// - Contas a Pagar (categorias)
/// - Contas a Receber (categorias)
/// - Contas Bancárias
/// - Formas de Pagamento/Recebimento
class TablesHomeScreen extends StatelessWidget {
  const TablesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FFScreenScaffold(
      title: 'Tabelas',
      showAppBar: false,
      useScrollView: true,
      verticalPadding: AppSpacing.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FFSection(
            title: 'Cadastros',
            icon: Icons.table_chart_outlined,
            subtitle: 'Gerencie categorias, bancos e formas de pagamento',
            bottomSpacing: AppSpacing.md,
            child: Column(
              children: [
                // Contas a Pagar (categorias)
                FFMenuActionCard(
                  icon: Icons.payments_outlined,
                  iconColor: Colors.red.shade600,
                  title: 'Contas a Pagar',
                  subtitle: 'Categorias para despesas e pagamentos',
                  onTap: () => _navigateTo(context, const PayCategoriesScreen()),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Contas a Receber (categorias)
                FFMenuActionCard(
                  icon: Icons.request_quote_outlined,
                  iconColor: Colors.green.shade600,
                  title: 'Contas a Receber',
                  subtitle: 'Categorias para receitas e recebimentos',
                  onTap: () => _navigateTo(context, const ReceiveCategoriesScreen()),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Contas Bancárias
                FFMenuActionCard(
                  icon: Icons.account_balance_outlined,
                  iconColor: Colors.blue.shade600,
                  title: 'Contas Bancárias',
                  subtitle: 'Gerencie suas contas em bancos',
                  onTap: () => _navigateTo(context, const BankAccountsScreen()),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Formas de Pagamento
                FFMenuActionCard(
                  icon: Icons.payment_outlined,
                  iconColor: Colors.orange.shade600,
                  title: 'Formas de Pagamento',
                  subtitle: 'Cartão, boleto, PIX, dinheiro, etc.',
                  onTap: () => _navigateTo(context, const PaymentMethodsScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
