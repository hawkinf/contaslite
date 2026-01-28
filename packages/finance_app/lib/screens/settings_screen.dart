import 'package:flutter/material.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';
import '../ui/components/app_modal_header.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_radius.dart';
import '../ui/theme/app_shadows.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/sync_service.dart';
import '../models/user.dart';
import '../database/sync_helpers.dart';
import 'database_screen.dart';
import 'email_settings_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<String> _cities;
  late String _selectedCity;
  bool _citiesInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedCity = PrefsService.cityNotifier.value;
    _initializeCities();
  }

  void _initializeCities() {
    if (!_citiesInitialized) {
      _cities = HolidayService.regions.values.expand((items) => items).toSet().toList()
        ..sort();
      _citiesInitialized = true;

      if (!_cities.contains(_selectedCity) && _cities.isNotEmpty) {
        _selectedCity = _cities.first;
      }
    }
  }

  void _ensureCitiesInitialized() {
    if (!_citiesInitialized) {
      _initializeCities();
    }
  }

  String _regionForCity(String city) {
    for (final entry in HolidayService.regions.entries) {
      if (entry.value.contains(city)) {
        return entry.key;
      }
    }
    return HolidayService.regions.keys.first;
  }

  // ============================================================
  // Premium Card Builder
  // ============================================================

  Widget _buildPremiumCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : AppColors.border;

    Widget card = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isDark ? null : AppShadows.soft,
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: card,
        ),
      );
    }

    return card;
  }

  // ============================================================
  // Section Title Builder
  // ============================================================

  Widget _buildSectionTitle(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // About Card (Compacto)
  // ============================================================

  Widget _buildAboutCard() {
    return _buildPremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Logo
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FácilFin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'v1.00 · Build 20251208',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Desenvolvido por Aguinaldo Liesack Baptistini',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Account Section
  // ============================================================

  Widget _buildAccountSection() {
    return ValueListenableBuilder<User?>(
      valueListenable: AuthService.instance.currentUserNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return _buildLoginPrompt();
        }
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildLoginPrompt() {
    return _buildPremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Modo Offline',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Faça login para sincronizar seus dados entre dispositivos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _goToLogin,
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Fazer Login'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return _buildPremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // User info row
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Name and email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Logout button
              Tooltip(
                message: 'Sair da conta',
                child: IconButton(
                  onPressed: _confirmLogout,
                  icon: Icon(
                    Icons.logout,
                    size: 20,
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Sync status
          ValueListenableBuilder<SyncState>(
            valueListenable: SyncService.instance.syncStateNotifier,
            builder: (context, syncState, _) {
              return _buildSyncStatusRow(syncState);
            },
          ),
          const SizedBox(height: 14),
          // Sync button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _manualSync,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sincronizar Agora'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusRow(SyncState state) {
    IconData icon;
    Color color;
    String text;
    Color bgColor;

    switch (state) {
      case SyncState.idle:
        icon = Icons.cloud_done;
        color = AppColors.success;
        text = 'Sincronizado';
        bgColor = AppColors.success.withValues(alpha: 0.1);
        break;
      case SyncState.syncing:
        icon = Icons.sync;
        color = Theme.of(context).colorScheme.primary;
        text = 'Sincronizando...';
        bgColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
        break;
      case SyncState.error:
        icon = Icons.cloud_off;
        color = AppColors.error;
        text = 'Erro na sincronização';
        bgColor = AppColors.error.withValues(alpha: 0.1);
        break;
      case SyncState.offline:
        icon = Icons.cloud_off_outlined;
        color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
        text = 'Offline';
        bgColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Location Section
  // ============================================================

  Widget _buildLocationCard() {
    return _buildPremiumCard(
      onTap: _showCitySelector,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.location_on,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cidade selecionada',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedCity,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // Chevron
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            size: 24,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Settings Tile Premium
  // ============================================================

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final effectiveIconColor = iconColor ?? Theme.of(context).colorScheme.primary;

    return _buildPremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              icon,
              color: effectiveIconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Chevron
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            size: 24,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // City Selector Dialog
  // ============================================================

  void _showCitySelector() {
    _ensureCitiesInitialized();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredCities = searchController.text.isEmpty
              ? _cities
              : _cities
                  .where((city) =>
                      city.toLowerCase().contains(searchController.text.toLowerCase()))
                  .toList();

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile ? 400 : 600,
                maxHeight: isMobile ? 600 : 500,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppModalHeader(
                    title: 'Selecionar Cidade',
                    onClose: () {
                      searchController.dispose();
                      Navigator.pop(context);
                    },
                    showDivider: false,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar cidade...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredCities.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_off,
                                    size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'Nenhuma cidade encontrada',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredCities.length,
                            itemBuilder: (context, index) {
                              final city = filteredCities[index];
                              final isSelected = city == _selectedCity;
                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                leading: Icon(
                                  Icons.location_on,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey,
                                ),
                                title: Text(city),
                                subtitle: Text(_regionForCity(city)),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).colorScheme.primary,
                                      )
                                    : null,
                                selected: isSelected,
                                selectedTileColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.3),
                                onTap: () {
                                  setState(() {
                                    _selectedCity = city;
                                  });
                                  PrefsService.saveLocation(_regionForCity(city), city);
                                  searchController.dispose();
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // Actions
  // ============================================================

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            const Text('Sair da conta'),
          ],
        ),
        content: const Text(
          'Deseja realmente sair? Seus dados locais serão mantidos, '
          'mas não serão mais sincronizados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.instance.logout();
      await GoogleAuthService.instance.signOut();
      await SyncService.instance.resetSync();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _manualSync() async {
    final result = await SyncService.instance.fullSync();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Sincronização concluída!'
                : 'Erro: ${result.error}',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      );
    }
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferências'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Sobre o App
          _buildAboutCard(),
          const SizedBox(height: 32),

          // Seção: Conta
          _buildSectionTitle('CONTA', icon: Icons.person_outline),
          _buildAccountSection(),
          const SizedBox(height: 32),

          // Seção: Localização
          _buildSectionTitle('LOCALIZAÇÃO', icon: Icons.location_on_outlined),
          _buildLocationCard(),
          const SizedBox(height: 32),

          // Seção: Configurações Avançadas
          _buildSectionTitle('CONFIGURAÇÕES', icon: Icons.settings_outlined),
          _buildSettingsTile(
            icon: Icons.storage_outlined,
            title: 'Banco de Dados',
            subtitle: 'Backup, sincronização e configurações',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DatabaseScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.email_outlined,
            title: 'Notificações por Email',
            subtitle: 'Configurar envio automático de relatórios',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmailSettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
