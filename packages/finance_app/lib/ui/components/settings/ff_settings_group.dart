import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../cards/ff_card.dart';
import 'ff_settings_tile.dart';

/// Grupo de configurações do FácilFin Design System.
///
/// Agrupa múltiplos FFSettingsTile dentro de um FFCard único
/// com divisores suaves entre os itens.
class FFSettingsGroup extends StatelessWidget {
  /// Lista de tiles (FFSettingsTile com useCard: false)
  final List<FFSettingsTile> tiles;

  /// Se deve mostrar divisores entre os tiles
  final bool showDividers;

  /// Padding interno do card
  final EdgeInsetsGeometry? padding;

  const FFSettingsGroup({
    super.key,
    required this.tiles,
    this.showDividers = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FFCard(
      padding: padding ?? const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            // Override useCard to false for grouped tiles
            FFSettingsTile(
              key: tiles[i].key,
              icon: tiles[i].icon,
              iconColor: tiles[i].iconColor,
              title: tiles[i].title,
              subtitle: tiles[i].subtitle,
              onTap: tiles[i].onTap,
              showChevron: tiles[i].showChevron,
              trailing: tiles[i].trailing,
              enabled: tiles[i].enabled,
              useCard: false, // Important: no nested cards
            ),
            // Divider between tiles (not after last)
            if (showDividers && i < tiles.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
