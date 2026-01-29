import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/calendar_export_snapshot.dart';
import '../ui/components/ff_design_system.dart';
import '../ui/theme/app_colors.dart' as app_colors;

/// Widget de exportação visual do calendário.
///
/// Renderiza o calendário no mesmo layout do app, mas em formato
/// estático (sem animações/scroll) para captura como imagem.
///
/// Usa os componentes FF* do Design System.
class CalendarExportView extends StatelessWidget {
  /// Snapshot do estado do calendário
  final CalendarExportSnapshot snapshot;

  /// ScrollController opcional (para integração com captura)
  final ScrollController? scrollController;

  const CalendarExportView({
    super.key,
    required this.snapshot,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header com título do período
            _buildPeriodHeader(context),
            // Mode selector (visual, sem interação)
            AbsorbPointer(
              child: FFCalendarModeSelector(
                currentMode: snapshot.mode,
                onModeChanged: (_) {},
              ),
            ),
            // Totals bar
            FFCalendarTotalsBar(
              totals: snapshot.periodTotals,
              currencyFormatter: (value) => UtilBrasilFields.obterReal(value),
            ),
            // Conteúdo principal baseado no modo
            Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildCalendarContent(context),
              ),
            ),
            // Agenda do dia selecionado
            _buildAgendaSection(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Header com o período atual
  Widget _buildPeriodHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final modeLabel = switch (snapshot.mode) {
      FFCalendarViewMode.weekly => 'Semanal',
      FFCalendarViewMode.monthly => 'Mensal',
      FFCalendarViewMode.yearly => 'Anual',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month,
            color: colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calendário $modeLabel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  snapshot.periodLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Conteúdo principal do calendário baseado no modo
  Widget _buildCalendarContent(BuildContext context) {
    return switch (snapshot.mode) {
      FFCalendarViewMode.weekly => _buildWeeklyView(context),
      FFCalendarViewMode.monthly => _buildMonthlyView(context),
      FFCalendarViewMode.yearly => _buildYearlyView(context),
    };
  }

  /// View semanal - lista de 7 dias
  Widget _buildWeeklyView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: snapshot.weekDays.map((day) {
          final isSelected = DateUtils.isSameDay(day.date, snapshot.selectedDate);
          return FFWeekDayCard(
            day: day.date.day,
            dayName: day.dayName,
            isToday: day.isToday,
            isWeekend: day.isWeekend,
            totals: day.totals,
            onTap: null, // Sem interação no export
            currencyFormatter: (value) => UtilBrasilFields.obterReal(value),
            backgroundColor: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          );
        }).toList(),
      ),
    );
  }

  /// View mensal - grid de dias
  Widget _buildMonthlyView(BuildContext context) {
    final weekdayLabels = snapshot.density.weekdayLabels;

    return Column(
      children: [
        // Weekday row
        FFWeekdayRow(
          weekdayLabels: weekdayLabels,
          height: snapshot.density.weekdayRowHeight,
          fontSize: snapshot.density.weekdayFontSize,
        ),
        // Grid de dias
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: snapshot.monthCells.length,
          itemBuilder: (context, index) {
            final cell = snapshot.monthCells[index];
            final isSelected = DateUtils.isSameDay(cell.date, snapshot.selectedDate);

            return FFDayTile(
              day: cell.date.day,
              isToday: cell.isToday,
              isSelected: isSelected,
              isWeekend: cell.isWeekend,
              isHoliday: cell.isHoliday,
              holidayName: cell.holidayName,
              isOutsideMonth: cell.isOutsideMonth,
              totals: cell.totals,
              density: snapshot.density,
              onTap: null, // Sem interação no export
            );
          },
        ),
      ],
    );
  }

  /// View anual - grid de 12 meses
  Widget _buildYearlyView(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: snapshot.yearMonths.length,
      itemBuilder: (context, index) {
        final month = snapshot.yearMonths[index];
        return FFMiniMonthCard(
          monthName: month.monthName,
          isCurrentMonth: month.isCurrentMonth,
          totals: month.totals,
          onTap: null, // Sem interação no export
        );
      },
    );
  }

  /// Seção de agenda do dia selecionado
  Widget _buildAgendaSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header da agenda
          FFDateGroupHeader(
            date: snapshot.selectedDate,
            itemCount: snapshot.agendaItems.length,
            icon: Icons.event_note,
            title: snapshot.agendaTitle,
          ),
          // Lista de itens ou empty state
          if (snapshot.agendaItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: FFEmptyState.contas(
                description: 'Nenhum lançamento para este dia.',
              ),
            )
          else
            ...snapshot.agendaItems.map((item) => _buildAgendaItem(context, item)),
        ],
      ),
    );
  }

  /// Item individual da agenda
  Widget _buildAgendaItem(BuildContext context, CalendarAgendaItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final account = item.account;

    // Determinar cores e estilos
    Color accentColor;
    Color valueColor;
    if (item.isRecebimento) {
      accentColor = app_colors.AppColors.success;
      valueColor = app_colors.AppColors.success;
    } else if (item.isCard) {
      accentColor = app_colors.AppColors.primary;
      valueColor = app_colors.AppColors.primary;
    } else {
      accentColor = app_colors.AppColors.error;
      valueColor = app_colors.AppColors.error;
    }

    // Formatar valores
    final valueFormatted = UtilBrasilFields.obterReal(item.displayValue);
    final dayLabel = item.effectiveDate.day.toString().padLeft(2, '0');
    final weekdayLabel = DateFormat('EEE', 'pt_BR')
        .format(item.effectiveDate)
        .replaceAll('.', '')
        .toUpperCase();

    // Chips de estado
    final chips = <Widget>[];
    if (item.typeName != null && item.typeName!.isNotEmpty) {
      chips.add(FFMiniChip(
        label: item.typeName!,
        backgroundColor: colorScheme.surfaceContainerHighest,
        textColor: colorScheme.onSurfaceVariant,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
      ));
    }
    if (item.isPrevisao) {
      chips.add(FFMiniChip(
        label: 'Previsão',
        backgroundColor: Colors.orange.shade100,
        textColor: Colors.orange.shade800,
      ));
    } else if (item.isRecurrent) {
      chips.add(FFMiniChip(
        label: 'Lançado',
        backgroundColor: app_colors.AppColors.success.withValues(alpha: 0.15),
        textColor: Colors.green.shade700,
      ));
    }
    if (item.isCard) {
      chips.add(const FFMiniChip(label: 'Cartão'));
    }

    // Título e subtítulo
    String title = item.typeName ?? 'Outro';
    String subtitle = account.description;
    if (item.isCard && account.cardBank != null) {
      subtitle = '${account.cardBank} - ${account.cardBrand ?? ""}';
    }

    // Emoji do título
    String? titleEmoji;
    if (item.isCard) {
      titleEmoji = '💳';
    } else if (item.isRecebimento) {
      titleEmoji = '📈';
    } else {
      titleEmoji = '📉';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: FFAccountItemCard(
        datePill: FFDatePill(
          day: dayLabel,
          weekday: weekdayLabel,
          accentColor: accentColor,
        ),
        title: title,
        subtitle: subtitle,
        value: valueFormatted,
        valueColor: valueColor,
        chips: chips.take(3).toList(),
        accentColor: accentColor,
        density: FFCardDensity.compact,
        titleEmoji: titleEmoji,
        onTap: null, // Sem interação no export
      ),
    );
  }
}
