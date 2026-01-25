import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'transaction_form_base.dart';

class LancamentoFormPadrao extends StatelessWidget {
  final Widget typeContent;
  final Widget categoryContent;
  final Widget launchContent;
  final Widget descriptionValueContent;
  final Widget datesContent;
  final Widget? extraClassificationContent;
  final Widget optionsContent;
  final Widget? parcelasContent;
  final Widget? categoryTrailing;
  final EdgeInsetsGeometry padding;
  final bool useScroll;
  final double sectionGap;

  const LancamentoFormPadrao({
    super.key,
    required this.typeContent,
    required this.categoryContent,
    required this.launchContent,
    required this.descriptionValueContent,
    required this.datesContent,
    this.extraClassificationContent,
    required this.optionsContent,
    this.parcelasContent,
    this.categoryTrailing,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.useScroll = true,
    this.sectionGap = AppSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    // Construir o conteúdo da seção Classificação
    // Se extraClassificationContent estiver presente, mostrá-lo junto com categoryContent
    final classificationChild = extraClassificationContent != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              extraClassificationContent!,
              const SizedBox(height: 12),
              categoryContent,
            ],
          )
        : categoryContent;

    final sections = <TransactionFormSection>[
      TransactionFormSection(
        title: 'Tipo / Identificação',
        child: typeContent,
      ),
      TransactionFormSection(
        title: 'Categorias',
        trailing: categoryTrailing,
        child: classificationChild,
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
      if (parcelasContent != null)
        TransactionFormSection(
          title: 'Parcelamento',
          child: parcelasContent!,
        ),
      TransactionFormSection(
        title: 'Opções',
        child: optionsContent,
      ),
    ];

    return TransactionFormBase(
      sections: sections,
      padding: padding,
      useScroll: useScroll,
      sectionGap: sectionGap,
    );
  }
}