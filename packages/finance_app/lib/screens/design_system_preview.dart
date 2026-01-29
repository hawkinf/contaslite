import 'package:flutter/material.dart';
import '../ui/components/ff_design_system.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_radius.dart';
import '../ui/theme/app_spacing.dart';

/// Tela de preview do Design System FF*.
///
/// Acesso: rota oculta ou via debug menu.
/// Serve como catálogo para validar estilos rapidamente.
class DesignSystemPreview extends StatefulWidget {
  const DesignSystemPreview({super.key});

  @override
  State<DesignSystemPreview> createState() => _DesignSystemPreviewState();
}

class _DesignSystemPreviewState extends State<DesignSystemPreview> {
  bool _switchValue = true;
  String _dropdownValue = 'Opção 1';
  FFCalendarViewMode _calendarMode = FFCalendarViewMode.monthly;

  @override
  Widget build(BuildContext context) {
    return FFScreenScaffold(
      title: 'Design System FF*',
      appBarActions: [
        FFIconActionButton(
          icon: Icons.dark_mode,
          tooltip: 'Alternar tema',
          onPressed: () {},
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========================================
          // CARDS
          // ========================================
          FFSection(
            title: 'Cards',
            icon: Icons.credit_card,
            subtitle: 'Componentes de container com estilo premium',
            child: Column(
              children: [
                _buildSubsection('FFCard (Base)'),
                FFCard(
                  child: Text(
                    'FFCard é o container base do Design System. '
                    'Aplica radius lg (16), borda 1px, sombra suave no modo claro.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FFCard(
                  onTap: () => _showSnackBar('FFCard clicado!'),
                  child: const Text('FFCard clicável (com onTap)'),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFInfoCard'),
                FFInfoCard(
                  leading: FFInfoCardLeading(
                    child: Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: 'Título do InfoCard',
                  subtitle: 'Subtítulo secundário',
                  secondarySubtitle: 'Informação adicional',
                ),
                const SizedBox(height: AppSpacing.md),
                FFInfoCard.about(
                  logo: FFInfoCardLeading(
                    child: Icon(
                      Icons.flutter_dash,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  appName: 'FácilFin',
                  version: 'v1.0.0 · Build 20251208',
                  developer: 'Seu Nome',
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFActionCard'),
                FFActionCard(
                  icon: Icons.settings,
                  title: 'Configurações',
                  subtitle: 'Acesse as configurações do app',
                  onTap: () => _showSnackBar('Action card clicado!'),
                ),
                const SizedBox(height: AppSpacing.md),
                FFActionCard(
                  icon: Icons.storage,
                  iconColor: AppColors.success,
                  title: 'Banco de Dados',
                  subtitle: 'Backup e sincronização',
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.md),
                FFActionCard(
                  icon: Icons.delete_outline,
                  iconColor: AppColors.error,
                  title: 'Excluir Dados',
                  subtitle: 'Ação destrutiva',
                  onTap: () {},
                ),
              ],
            ),
          ),

          // ========================================
          // BUTTONS
          // ========================================
          FFSection(
            title: 'Buttons',
            icon: Icons.touch_app,
            subtitle: 'Botões primários, secundários e de ícone',
            child: Column(
              children: [
                _buildSubsection('FFPrimaryButton'),
                FFPrimaryButton(
                  label: 'Botão Primário',
                  icon: Icons.check,
                  onPressed: () => _showSnackBar('Primary!'),
                ),
                const SizedBox(height: AppSpacing.md),
                FFPrimaryButton(
                  label: 'Carregando...',
                  isLoading: true,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.md),
                FFPrimaryButton.danger(
                  label: 'Excluir',
                  icon: Icons.delete,
                  onPressed: () => _showSnackBar('Danger!'),
                ),
                const SizedBox(height: AppSpacing.md),
                const FFPrimaryButton(
                  label: 'Desabilitado',
                  onPressed: null,
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFSecondaryButton'),
                FFSecondaryButton(
                  label: 'Botão Secundário',
                  icon: Icons.sync,
                  onPressed: () => _showSnackBar('Secondary!'),
                ),
                const SizedBox(height: AppSpacing.md),
                FFSecondaryButton(
                  label: 'Tonal',
                  icon: Icons.palette,
                  tonal: true,
                  onPressed: () => _showSnackBar('Tonal!'),
                ),
                const SizedBox(height: AppSpacing.md),
                FFSecondaryButton(
                  label: 'Carregando...',
                  isLoading: true,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFIconActionButton'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        FFIconActionButton(
                          icon: Icons.edit,
                          tooltip: 'Editar',
                          onPressed: () {},
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text('Default', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                    Column(
                      children: [
                        FFIconActionButton.danger(
                          icon: Icons.delete,
                          tooltip: 'Excluir',
                          onPressed: () {},
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text('Danger', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                    Column(
                      children: [
                        FFIconActionButton.success(
                          icon: Icons.check,
                          tooltip: 'Confirmar',
                          onPressed: () {},
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text('Success', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                    Column(
                      children: [
                        FFIconActionButton(
                          icon: Icons.block,
                          tooltip: 'Desabilitado',
                          enabled: false,
                          onPressed: () {},
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text('Disabled', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ========================================
          // BADGES
          // ========================================
          FFSection(
            title: 'Badges',
            icon: Icons.label,
            subtitle: 'Indicadores de status',
            child: Column(
              children: [
                _buildSubsection('FFBadge por Tipo'),
                const Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FFBadge(
                      label: 'Success',
                      type: FFBadgeType.success,
                      icon: Icons.check_circle,
                    ),
                    FFBadge(
                      label: 'Error',
                      type: FFBadgeType.error,
                      icon: Icons.error,
                    ),
                    FFBadge(
                      label: 'Warning',
                      type: FFBadgeType.warning,
                      icon: Icons.warning,
                    ),
                    FFBadge(
                      label: 'Info',
                      type: FFBadgeType.info,
                      icon: Icons.info,
                    ),
                    FFBadge(
                      label: 'Neutral',
                      type: FFBadgeType.neutral,
                      icon: Icons.circle,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFBadge.syncStatus'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FFBadge.syncStatus(
                      label: 'Sincronizado',
                      isSynced: true,
                    ),
                    FFBadge.syncStatus(
                      label: 'Sincronizando...',
                      isSynced: false,
                    ),
                    FFBadge.syncStatus(
                      label: 'Offline',
                      isSynced: false,
                      isOffline: true,
                    ),
                    FFBadge.syncStatus(
                      label: 'Erro',
                      isSynced: false,
                      isError: true,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ========================================
          // SETTINGS
          // ========================================
          FFSection(
            title: 'Settings',
            icon: Icons.tune,
            subtitle: 'Componentes para telas de configuração',
            child: Column(
              children: [
                _buildSubsection('FFSettingsTile'),
                FFSettingsTile(
                  icon: Icons.notifications,
                  title: 'Notificações',
                  subtitle: 'Ativar alertas do app',
                  onTap: () => _showSnackBar('Settings tile!'),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFSettingsSwitchTile'),
                FFSettingsSwitchTile(
                  icon: Icons.dark_mode,
                  title: 'Modo Escuro',
                  subtitle: 'Usar tema escuro',
                  value: _switchValue,
                  onChanged: (value) {
                    setState(() => _switchValue = value);
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFSettingsDropdownTile'),
                FFSettingsDropdownTile<String>(
                  icon: Icons.language,
                  title: 'Idioma',
                  subtitle: 'Selecione o idioma',
                  value: _dropdownValue,
                  items: const [
                    DropdownMenuItem(value: 'Opção 1', child: Text('Português')),
                    DropdownMenuItem(value: 'Opção 2', child: Text('English')),
                    DropdownMenuItem(value: 'Opção 3', child: Text('Español')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _dropdownValue = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFSettingsGroup'),
                FFSettingsGroup(
                  tiles: [
                    FFSettingsTile(
                      icon: Icons.person,
                      title: 'Perfil',
                      subtitle: 'Editar informações',
                      onTap: () {},
                    ),
                    FFSettingsTile(
                      icon: Icons.security,
                      title: 'Segurança',
                      subtitle: 'Senha e autenticação',
                      onTap: () {},
                    ),
                    FFSettingsTile(
                      icon: Icons.help,
                      title: 'Ajuda',
                      subtitle: 'FAQ e suporte',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ========================================
          // TYPOGRAPHY
          // ========================================
          FFSection(
            title: 'Typography',
            icon: Icons.text_fields,
            subtitle: 'Componentes de texto especializados',
            child: Column(
              children: [
                _buildSubsection('FFMoneyText'),
                FFCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Receita:'),
                          FFMoneyText.income(value: 1500.00),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Despesa:'),
                          FFMoneyText.expense(value: -750.50),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Neutro:'),
                          FFMoneyText.neutral(value: 0.00),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Oculto:'),
                          FFMoneyText(value: 999.99, hidden: true),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Automático:'),
                          FFMoneyText(value: 250.00, colorBySig: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ========================================
          // LAYOUT
          // ========================================
          FFSection(
            title: 'Layout',
            icon: Icons.dashboard,
            subtitle: 'Componentes estruturais',
            bottomSpacing: 0,
            child: Column(
              children: [
                _buildSubsection('FFScreenScaffold'),
                FFCard(
                  child: Text(
                    'Esta própria tela usa FFScreenScaffold!\n\n'
                    '• AppBar padronizada (FFAppBar)\n'
                    '• Padding horizontal 20\n'
                    '• Padding vertical 24\n'
                    '• ScrollView automático\n'
                    '• SafeArea automática',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFSection'),
                FFCard(
                  child: Text(
                    'Cada seção desta tela usa FFSection!\n\n'
                    '• Título em uppercase\n'
                    '• Ícone opcional\n'
                    '• Subtítulo opcional\n'
                    '• Espaçamento consistente (32)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ========================================
          // CALENDAR
          // ========================================
          FFSection(
            title: 'Calendar',
            icon: Icons.calendar_month,
            subtitle: 'Componentes de calendário',
            child: Column(
              children: [
                _buildSubsection('FFWeekdayRow'),
                FFCard(
                  child: Column(
                    children: [
                      const Text('Default (regular)'),
                      const SizedBox(height: AppSpacing.sm),
                      FFWeekdayRow(),
                      const SizedBox(height: AppSpacing.md),
                      const Text('Compact (mobile)'),
                      const SizedBox(height: AppSpacing.sm),
                      FFWeekdayRow.compact(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFCalendarModeSelector'),
                FFCalendarModeSelector(
                  currentMode: _calendarMode,
                  onModeChanged: (mode) {
                    setState(() => _calendarMode = mode);
                    _showSnackBar('Modo: ${mode.label}');
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                FFCalendarModeSelector.compact(
                  currentMode: _calendarMode,
                  onModeChanged: (mode) => setState(() => _calendarMode = mode),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFCalendarTotalsBar'),
                const FFCalendarTotalsBar(
                  totals: FFPeriodTotals(
                    totalPagar: 5250.00,
                    totalReceber: 8750.00,
                    countPagar: 12,
                    countReceber: 5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFDayTile (variações)'),
                const FFCard(
                  child: SizedBox(
                    height: 120,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text('Normal', style: TextStyle(fontSize: 10)),
                              Expanded(
                                child: FFDayTile(day: 15),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text('Hoje', style: TextStyle(fontSize: 10)),
                              Expanded(
                                child: FFDayTile(day: 20, isToday: true),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text('Selecionado', style: TextStyle(fontSize: 10)),
                              Expanded(
                                child: FFDayTile(day: 10, isSelected: true),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text('Feriado', style: TextStyle(fontSize: 10)),
                              Expanded(
                                child: FFDayTile(day: 25, isHoliday: true),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text('Fora', style: TextStyle(fontSize: 10)),
                              Expanded(
                                child: FFDayTile(day: 5, isOutsideMonth: true),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFWeekDayCard'),
                const FFWeekDayCard(
                  day: 15,
                  dayName: 'SEG',
                  totals: FFDayTotals(
                    totalPagar: 1500,
                    countPagar: 2,
                    totalReceber: 3000,
                    countReceber: 1,
                  ),
                ),
                const FFWeekDayCard(
                  day: 16,
                  dayName: 'TER',
                  isToday: true,
                  totals: FFDayTotals(
                    totalPagar: 500,
                    countPagar: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFMiniMonthCard'),
                const SizedBox(
                  height: 100,
                  child: Row(
                    children: [
                      Expanded(
                        child: FFMiniMonthCard(
                          monthName: 'Jan',
                          totals: FFPeriodTotals(
                            totalPagar: 5000,
                            countPagar: 10,
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FFMiniMonthCard(
                          monthName: 'Fev',
                          isCurrentMonth: true,
                          totals: FFPeriodTotals(
                            totalPagar: 3000,
                            totalReceber: 5000,
                            countPagar: 5,
                            countReceber: 3,
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FFMiniMonthCard(monthName: 'Mar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('FFDayDetailsModal'),
                FFSecondaryButton(
                  label: 'Abrir Modal de Detalhes',
                  icon: Icons.open_in_new,
                  onPressed: () {
                    FFDayDetailsModal.show(
                      context: context,
                      date: DateTime.now(),
                      dateFormatted: '15 de Janeiro de 2024',
                      weekdayName: 'Segunda-feira',
                      totals: const FFDayTotals(
                        totalPagar: 1500,
                        countPagar: 3,
                        totalReceber: 2500,
                        countReceber: 2,
                      ),
                      eventsBuilder: (controller) => ListView(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        children: const [
                          Text('Lista de eventos do dia apareceria aqui...'),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ========================================
          // THEME TOKENS
          // ========================================
          FFSection(
            title: 'Theme Tokens',
            icon: Icons.palette,
            subtitle: 'Cores, espaçamentos e raios',
            bottomSpacing: 0,
            child: Column(
              children: [
                _buildSubsection('AppColors'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _buildColorChip('success', AppColors.success),
                    _buildColorChip('error', AppColors.error),
                    _buildColorChip('border', AppColors.border),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('AppRadius'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _buildRadiusChip('sm', AppRadius.sm),
                    _buildRadiusChip('md', AppRadius.md),
                    _buildRadiusChip('lg', AppRadius.lg),
                    _buildRadiusChip('xl', AppRadius.xl),
                    _buildRadiusChip('xxl', AppRadius.xxl),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSubsection('AppSpacing'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _buildSpacingChip('xs', AppSpacing.xs),
                    _buildSpacingChip('sm', AppSpacing.sm),
                    _buildSpacingChip('md', AppSpacing.md),
                    _buildSpacingChip('lg', AppSpacing.lg),
                    _buildSpacingChip('xl', AppSpacing.xl),
                    _buildSpacingChip('xxl', AppSpacing.xxl),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildSubsection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildColorChip(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusChip(String name, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(value),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        '$name: ${value.toInt()}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSpacingChip(String name, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '$name: ${value.toInt()}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}
