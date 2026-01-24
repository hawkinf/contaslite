import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'transaction_form_base.dart';

class LancamentoFormPadrao extends StatelessWidget {
  final Widget typeContent;
  final Widget categoryContent;
  final Widget launchContent;
  final Widget descriptionValueContent;
  final Widget datesContent;
  final Widget optionsContent;
  final Widget? parcelasContent;
  final Widget? categoryTrailing;
  final EdgeInsetsGeometry padding;
  final bool useScroll;

  const LancamentoFormPadrao({
    super.key,
    required this.typeContent,
    required this.categoryContent,
    required this.launchContent,
    required this.descriptionValueContent,
    required this.datesContent,
    required this.optionsContent,
    this.parcelasContent,
    this.categoryTrailing,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.useScroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <TransactionFormSection>[
      TransactionFormSection(
        title: 'Tipo / Identificação',
        child: typeContent,
      ),
      TransactionFormSection(
        title: 'Categoria',
        trailing: categoryTrailing,
        child: categoryContent,
      ),
      TransactionFormSection(
        title: 'Lançamento',
        child: launchContent,
      ),
      TransactionFormSection(
        title: 'Descrição / Valor',
        child: descriptionValueContent,
      ),
      TransactionFormSection(
        title: 'Datas',
        child: datesContent,
      ),
      TransactionFormSection(
        title: 'Opções',
        child: optionsContent,
      ),
    ];

    if (parcelasContent != null) {
      sections.add(
        TransactionFormSection(
          title: 'Parcelamento',
          child: parcelasContent!,
        ),
      );
    }

    return TransactionFormBase(
      sections: sections,
      padding: padding,
      useScroll: useScroll,
    );
  }
}