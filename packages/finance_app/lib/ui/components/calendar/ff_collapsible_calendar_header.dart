import 'package:flutter/material.dart';
import 'ff_calendar_density.dart';
import 'ff_calendar_mode_selector.dart';
import 'ff_calendar_totals_bar.dart';

/// Configuração do header colapsável
class FFCollapsibleHeaderConfig {
  /// Altura expandida
  final double expandedHeight;

  /// Altura colapsada
  final double collapsedHeight;

  /// Threshold para colapsar (pixels de scroll)
  final double collapseThreshold;

  /// Threshold para expandir (histerese)
  final double expandThreshold;

  /// Duração da animação
  final Duration animationDuration;

  /// Curva da animação
  final Curve animationCurve;

  const FFCollapsibleHeaderConfig({
    this.expandedHeight = 180,
    this.collapsedHeight = 88,
    this.collapseThreshold = 70,
    this.expandThreshold = 30,
    this.animationDuration = const Duration(milliseconds: 180),
    this.animationCurve = Curves.easeOut,
  });

  /// Configuração padrão
  static const defaultConfig = FFCollapsibleHeaderConfig();

  /// Configuração compacta para mobile
  static const compactConfig = FFCollapsibleHeaderConfig(
    expandedHeight: 160,
    collapsedHeight: 80,
    collapseThreshold: 50,
    expandThreshold: 20,
  );
}

/// Header colapsável do calendário do FácilFin Design System.
///
/// Combina o seletor de modo, barra de totais e linha de weekdays
/// com comportamento de colapso suave ao rolar.
///
/// Implementa histerese para evitar "flickering" durante scroll.
///
/// Exemplo de uso:
/// ```dart
/// FFCollapsibleCalendarHeader(
///   scrollController: _scrollController,
///   currentMode: FFCalendarViewMode.monthly,
///   onModeChanged: (mode) => setState(() => _viewMode = mode),
///   totals: _monthTotals,
///   density: FFCalendarDensity.regular,
///   weekdayRow: FFWeekdayRow(),
/// )
/// ```
class FFCollapsibleCalendarHeader extends StatefulWidget {
  /// Controller de scroll para detectar posição
  final ScrollController scrollController;

  /// Modo atual do calendário
  final FFCalendarViewMode currentMode;

  /// Callback quando o modo muda
  final ValueChanged<FFCalendarViewMode> onModeChanged;

  /// Totais do período
  final FFPeriodTotals totals;

  /// Densidade da UI
  final FFCalendarDensity density;

  /// Widget de weekday row (permanece fixo)
  final Widget? weekdayRow;

  /// Se deve mostrar o mode selector
  final bool showModeSelector;

  /// Se deve mostrar a barra de totais
  final bool showTotalsBar;

  /// Configuração do comportamento de colapso
  final FFCollapsibleHeaderConfig config;

  /// Widget adicional no header (título do mês, etc)
  final Widget? titleWidget;

  /// Formatador de moeda
  final String Function(double)? currencyFormatter;

  const FFCollapsibleCalendarHeader({
    super.key,
    required this.scrollController,
    required this.currentMode,
    required this.onModeChanged,
    required this.totals,
    this.density = FFCalendarDensity.regular,
    this.weekdayRow,
    this.showModeSelector = true,
    this.showTotalsBar = true,
    this.config = const FFCollapsibleHeaderConfig(),
    this.titleWidget,
    this.currencyFormatter,
  });

  @override
  State<FFCollapsibleCalendarHeader> createState() =>
      _FFCollapsibleCalendarHeaderState();
}

class _FFCollapsibleCalendarHeaderState
    extends State<FFCollapsibleCalendarHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _collapseAnimation;
  bool _isCollapsed = false;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.config.animationDuration,
    );
    _collapseAnimation = CurvedAnimation(
      parent: _animationController,
      curve: widget.config.animationCurve,
    );
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = widget.scrollController.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;

    // Implementa histerese para evitar flickering
    if (!_isCollapsed && offset > widget.config.collapseThreshold && delta > 0) {
      _collapse();
    } else if (_isCollapsed && offset < widget.config.expandThreshold && delta < 0) {
      _expand();
    }
  }

  void _collapse() {
    if (_isCollapsed) return;
    setState(() => _isCollapsed = true);
    _animationController.forward();
  }

  void _expand() {
    if (!_isCollapsed) return;
    setState(() => _isCollapsed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _collapseAnimation,
      builder: (context, child) {
        final collapseValue = _collapseAnimation.value;
        final currentHeight = widget.config.expandedHeight -
            (widget.config.expandedHeight - widget.config.collapsedHeight) *
                collapseValue;

        return Container(
          height: currentHeight,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: collapseValue > 0.5
                ? [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              // Parte colapsável (mode selector + title + totals)
              Expanded(
                child: ClipRect(
                  child: Opacity(
                    opacity: 1 - collapseValue * 0.3, // Fading suave
                    child: Transform.translate(
                      offset: Offset(0, -collapseValue * 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title widget (se existir)
                          if (widget.titleWidget != null) widget.titleWidget!,

                          // Mode selector
                          if (widget.showModeSelector)
                            AnimatedContainer(
                              duration: widget.config.animationDuration,
                              height: _isCollapsed
                                  ? 0
                                  : widget.density.modeSelectorHeight,
                              child: _isCollapsed
                                  ? null
                                  : FFCalendarModeSelector(
                                      currentMode: widget.currentMode,
                                      onModeChanged: widget.onModeChanged,
                                      height: widget.density.modeSelectorHeight,
                                      useShortLabels:
                                          widget.density.useShortLabels,
                                      showBottomBorder: false,
                                    ),
                            ),

                          // Totals bar
                          if (widget.showTotalsBar)
                            AnimatedContainer(
                              duration: widget.config.animationDuration,
                              height: _isCollapsed
                                  ? 0
                                  : widget.density.totalsBarHeight,
                              child: _isCollapsed
                                  ? null
                                  : FFCalendarTotalsBar(
                                      totals: widget.totals,
                                      compact:
                                          widget.density == FFCalendarDensity.compact,
                                      showBottomBorder: false,
                                      currencyFormatter: widget.currencyFormatter,
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Weekday row (sempre visível)
              if (widget.weekdayRow != null) widget.weekdayRow!,
            ],
          ),
        );
      },
    );
  }
}

/// Delegate para uso com SliverPersistentHeader
class FFCollapsibleCalendarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double expandedHeight;
  final double collapsedHeight;
  final ColorScheme colorScheme;

  FFCollapsibleCalendarHeaderDelegate({
    required this.child,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.colorScheme,
  });

  @override
  double get minExtent => collapsedHeight;

  @override
  double get maxExtent => expandedHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: overlapsContent || progress > 0.5
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant FFCollapsibleCalendarHeaderDelegate oldDelegate) {
    return child != oldDelegate.child ||
        expandedHeight != oldDelegate.expandedHeight ||
        collapsedHeight != oldDelegate.collapsedHeight;
  }
}
