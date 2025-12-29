class DefaultAccountCategory {
  final String category;
  final List<String> subcategories;

  DefaultAccountCategory({
    required this.category,
    required this.subcategories,
  });
}

class DefaultAccountCategoriesService {
  static final DefaultAccountCategoriesService instance =
      DefaultAccountCategoriesService._();
  DefaultAccountCategoriesService._();

  static const List<Map<String, dynamic>> defaultCategories = [
    {
      'category': 'Cartões de Crédito',
      'subcategories': [
        'AMEX',
        'VISA',
        'MASTERCARD',
        'ELO',
      ],
    },
    {
      'category': 'Moradia',
      'subcategories': [
        'Aluguel',
        'Condomínio',
        'IPTU e taxas',
      ],
    },
    {
      'category': 'Consumo',
      'subcategories': [
        'Energia Elétrica',
        'Água / esgoto',
        'Gás',
        'Internet',
        'Telefonia',
        'TV / streaming',
      ],
    },
    {
      'category': 'Alimentação',
      'subcategories': [
        'Supermercado',
        'Açougue',
      ],
    },
    {
      'category': 'Transporte',
      'subcategories': [
        'Combustível',
        'Manutenção',
        'Seguro',
        'Impostos e multas',
        'Uber',
      ],
    },
    {
      'category': 'Saúde',
      'subcategories': [
        'Plano de saúde',
        'Consultas',
        'Exames',
        'Medicamentos',
        'Dentista',
        'Terapias',
      ],
    },
    {
      'category': 'Educação',
      'subcategories': [
        'Escola / faculdade',
        'Cursos',
        'Livros / materiais',
        'Idiomas',
      ],
    },
    {
      'category': 'Lazer e Viagens',
      'subcategories': [
        'Viagens',
        'Passeios',
        'Hobbies',
        'Shows',
        'Restaurantes e bares',
      ],
    },
    {
      'category': 'Assinaturas e serviços digitais',
      'subcategories': [
        'Streaming',
        'Música',
        'Nuvem (Google/Apple/MS)',
      ],
    },
    {
      'category': 'Dívidas',
      'subcategories': [
        'Empréstimo',
        'Financiamento veículo',
        'Financiamento imobiliário',
        'Consórcio',
        'Acordos/renegociações',
      ],
    },
    {
      'category': 'Diversos',
      'subcategories': [
        'Perdas',
        'Outros',
      ],
    },
  ];

  List<DefaultAccountCategory> getDefaultCategories() {
    return defaultCategories
        .map((item) => DefaultAccountCategory(
              category: item['category'] as String,
              subcategories:
                  List<String>.from(item['subcategories'] as List<dynamic>),
            ))
        .toList();
  }

  Map<String, List<String>> getCategoriesAsMap() {
    final map = <String, List<String>>{};
    for (final item in defaultCategories) {
      map[item['category'] as String] =
          List<String>.from(item['subcategories'] as List<dynamic>);
    }
    return map;
  }
}
