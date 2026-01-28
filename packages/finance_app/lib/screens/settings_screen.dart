import 'package:flutter/material.dart';
import '../database/sync_helpers.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';
import '../ui/components/app_modal_header.dart';
import '../ui/components/ff_design_system.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_radius.dart';
import '../ui/theme/app_spacing.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/sync_service.dart';
import '../models/user.dart';
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
  // About Card (usando FFInfoCard.about)
  // ============================================================

  Widget _buildAboutCard() {
    return FFInfoCard.about(
      logo: FFInfoCardLeading(
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.contain,
        ),
      ),
      appName: 'FácilFin',
      version: 'v1.00 · Build 20251208',
      developer: 'Aguinaldo Liesack Baptistini',
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
    final theme = Theme.of(context);

    return FFCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          // Icon container
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_outlined,
              size: 32,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Modo Offline',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Faça login para sincronizar seus dados entre dispositivos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FFPrimaryButton(
            label: 'Fazer Login',
            icon: Icons.login,
            onPressed: _goToLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final theme = Theme.of(context);

    return FFCard(
      child: Column(
        children: [
          // User info row
          Row(
            children: [
              // Avatar com gradiente
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
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
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Logout button
              FFIconActionButton.danger(
                icon: Icons.logout,
                tooltip: 'Sair da conta',
                onPressed: _confirmLogout,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Sync status badge
          ValueListenableBuilder<SyncState>(
            valueListenable: SyncService.instance.syncStateNotifier,
            builder: (context, syncState, _) {
              return _buildSyncStatusBadge(syncState);
            },
          ),
          const SizedBox(height: 14),
          // Sync button
          FFSecondaryButton(
            label: 'Sincronizar Agora',
            icon: Icons.sync,
            onPressed: _manualSync,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusBadge(SyncState state) {
    String label = '';
    bool isSynced = false;
    bool isOffline = false;
    bool isError = false;

    switch (state) {
      case SyncState.idle:
        label = 'Sincronizado';
        isSynced = true;
      case SyncState.syncing:
        label = 'Sincronizando...';
      case SyncState.error:
        label = 'Erro na sincronização';
        isError = true;
      case SyncState.offline:
        label = 'Offline';
        isOffline = true;
    }

    return FFBadge.syncStatus(
      label: label,
      isSynced: isSynced,
      isOffline: isOffline,
      isError: isError,
    );
  }

  // ============================================================
  // Location Section (usando FFActionCard)
  // ============================================================

  Widget _buildLocationCard() {
    return FFCard(
      onTap: _showCitySelector,
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
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                  const SizedBox(height: AppSpacing.lg),
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
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: filteredCities.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_off,
                                    size: 48, color: Colors.grey[400]),
                                const SizedBox(height: AppSpacing.md),
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
                              final theme = Theme.of(context);

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedCity = city;
                                  });
                                  PrefsService.saveLocation(_regionForCity(city), city);
                                  searchController.dispose();
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.md,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                                        : null,
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              city,
                                              style: TextStyle(
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            Text(
                                              _regionForCity(city),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: theme.colorScheme.primary,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
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
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.error),
            SizedBox(width: AppSpacing.md),
            Text('Sair da conta'),
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
          FFPrimaryButton.danger(
            label: 'Sair',
            onPressed: () => Navigator.pop(context, true),
            expanded: false,
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
    return FFScreenScaffold(
      title: 'Preferências',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sobre o App
          _buildAboutCard(),
          const SizedBox(height: AppSpacing.xxl),

          // Seção: Conta
          FFSection(
            title: 'Conta',
            icon: Icons.person_outline,
            bottomSpacing: 0,
            child: _buildAccountSection(),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Seção: Localização
          FFSection(
            title: 'Localização',
            icon: Icons.location_on_outlined,
            bottomSpacing: 0,
            child: _buildLocationCard(),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Seção: Configurações
          FFSection(
            title: 'Configurações',
            icon: Icons.settings_outlined,
            bottomSpacing: 0,
            child: Column(
              children: [
                FFActionCard(
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
                const SizedBox(height: AppSpacing.md),
                FFActionCard(
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
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
