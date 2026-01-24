import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'section_card.dart';

class TransactionFormSection {
  final String title;
  final Widget child;
  final Widget? trailing;

  const TransactionFormSection({
    required this.title,
    required this.child,
    this.trailing,
  });
}

class TransactionFormBase extends StatelessWidget {
  final List<TransactionFormSection> sections;
  final EdgeInsetsGeometry padding;
  final double sectionGap;
  final bool useScroll;

  const TransactionFormBase({
    super.key,
    required this.sections,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.sectionGap = AppSpacing.md,
    this.useScroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < sections.length; i++) ...[
            SectionCard(
              title: sections[i].title,
              trailing: sections[i].trailing,
              child: sections[i].child,
            ),
            if (i != sections.length - 1) SizedBox(height: sectionGap),
          ],
        ],
      ),
    );

    if (!useScroll) {
      return content;
    }

    return SingleChildScrollView(
      child: content,
    );
  }
}
