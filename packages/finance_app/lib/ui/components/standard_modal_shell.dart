import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'app_modal_header.dart';

class StandardModalShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onClose;
  final Widget body;
  final Widget? footer;
  final EdgeInsetsGeometry bodyPadding;
  final bool scrollBody;
  final double maxWidth;
  final double maxHeight;
  /// Se true, o modal ajusta sua altura ao conteúdo (não expande até maxHeight)
  final bool shrinkWrap;

  const StandardModalShell({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.onClose,
    this.footer,
    this.bodyPadding = const EdgeInsets.all(AppSpacing.md),
    this.scrollBody = true,
    this.maxWidth = 860,
    this.maxHeight = 850,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: bodyPadding,
      child: body,
    );

    // Se shrinkWrap, não usa Expanded (ajusta ao conteúdo)
    final bodyWidget = shrinkWrap
        ? (scrollBody ? SingleChildScrollView(child: content) : content)
        : Expanded(
            child: scrollBody ? SingleChildScrollView(child: content) : content,
          );

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
            children: [
              AppModalHeader(
                title: title,
                subtitle: subtitle,
                actions: actions,
                onClose: onClose,
              ),
              bodyWidget,
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}