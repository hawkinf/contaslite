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

  static const String recebimentosName = 'Recebimentos';
  static const String recebimentosChildSeparator = '||';

  // Subcategorias de Recebimentos para Pessoa Física
  static const Map<String, List<String>> recebimentosChildDefaultsPF = {
    'Salário/Pró-Labore': [
      '13º Salário',
      'Abono de Férias',
      'Adiantamento Salarial',
      'Bônus',
      'Férias',
      'PLR',
      'Pró-labore',
      'Salário Mensal',
      'Outros',
    ],
    'Aposentadoria/Benefícios': [
      'Auxílios',
      'INSS',
      'Pensão',
      'Previdência Privada',
      'Outros',
    ],
    'Outras Receitas': [
      'Ajustes Positivos',
      'Ganhos Eventuais',
      'Indenizações',
      'Restituições',
      'Venda de Bens',
      'Outros',
    ],
    'Presentes/Doações': [
      'Ajuda Familiar',
      'Doações',
      'Herança',
      'Mesada',
      'Premiações',
      'Presentes/Doações',
      'Outros',
    ],
    'Reembolsos e Restituições': [
      'Ajustes',
      'Ajustes Positivos',
      'Devoluções',
      'Estornos',
      'Médico',
      'Trabalho',
      'Viagem',
      'Reembolso (empresa)',
      'Reembolso (saúde)',
      'Restituição IRPF',
      'Outros',
    ],
    'Rendas de Aluguel': [
      'Arrendamento',
      'Comercial',
      'Equipamentos',
      'Garagem',
      'Residencial',
      'Outros',
    ],
    'Receitas Financeiras': [
      'Cashback',
      'Dividendos',
      'Juros recebidos',
      'Rendimentos (aplicações)',
      'Outros',
    ],
    'Trabalho Autônomo': [
      'Bicos',
      'Comissões',
      'Consultorias',
      'Diárias',
      'Freelance',
      'Honorários',
      'Serviços Eventuais',
      'Outros',
    ],
  };

  // Subcategorias de Recebimentos para Pessoa Jurídica
  static const Map<String, List<String>> recebimentosChildDefaultsPJ = {
    'Vendas': [
      'Marketplace',
      'Venda à vista (PIX/dinheiro)',
      'Vendas com cartão',
      'Outros',
    ],
    'Serviços': [
      'Consultoria',
      'Contrato mensal (recorrente)',
      'Instalação/Projeto',
      'Manutenção',
      'Serviço avulso',
      'Suporte',
      'Outros',
    ],
    'Recebimentos Financeiros': [
      'Cashback',
      'Juros recebidos',
      'Rendimentos (aplicações)',
      'Outros',
    ],
    'Reembolsos e Ajustes': [
      'Ajustes/Acertos',
      'Estornos recebidos',
      'Reembolsos/Ressarcimentos',
      'Outros',
    ],
    'Vendas de Ativos': [
      'Venda de ativo (equipamento/usado)',
      'Outros',
    ],
  };

  // Subcategorias de Recebimentos para Ambos (PF e PJ)
  static const Map<String, List<String>> recebimentosChildDefaultsAmbos = {
    'Vendas': [
      'Marketplace',
      'Venda à vista (PIX/dinheiro)',
      'Vendas com cartão',
      'Outros',
    ],
    'Serviços': [
      'Consultoria',
      'Contrato mensal (recorrente)',
      'Instalação/Projeto',
      'Manutenção',
      'Serviço avulso',
      'Suporte',
      'Outros',
    ],
    'Salário/Pró-Labore': [
      '13º Salário',
      'Abono de Férias',
      'Adiantamento Salarial',
      'Bônus',
      'Férias',
      'PLR',
      'Pró-Labore',
      'Salário Mensal',
    ],
    'Aposentadoria/Benefícios': [
      'Auxílios',
      'INSS',
      'Pensão',
      'Previdência Privada',
    ],
    'Outras Receitas': [
      'Ajustes Positivos',
      'Ganhos Eventuais',
      'Indenizações',
      'Restituições',
      'Venda de Bens',
    ],
    'Presentes/Doações': [
      'Ajuda Familiar',
      'Doações',
      'Herança',
      'Mesada',
      'Premiações',
      'Presentes/Doações',
    ],
    'Rendas de Aluguel': [
      'Arrendamento',
      'Comercial',
      'Equipamentos',
      'Garagem',
      'Residencial',
    ],
    'Receitas Financeiras': [
      'Cashback',
      'Dividendos',
      'Juros recebidos',
      'Rendimentos (aplicações)',
      'Outros',
    ],
    'Trabalho Autônomo': [
      'Bicos',
      'Comissões',
      'Consultorias',
      'Diárias',
      'Freelance',
      'Honorários',
      'Serviços Eventuais',
    ],
    'Reembolsos e Ajustes': [
      'Ajustes/Acertos',
      'Devoluções',
      'Estornos',
      'Estornos recebidos',
      'Médico',
      'Trabalho',
      'Viagem',
      'Reembolso (empresa)',
      'Reembolso (saúde)',
      'Reembolsos/Ressarcimentos',
      'Restituição IRPF',
      'Outros',
    ],
    'Vendas de Ativos': [
      'Venda de ativo (equipamento/usado)',
      'Outros',
    ],
  };

  // Getter para manter compatibilidade - retorna baseado no tipo padrão
  static Map<String, List<String>> get recebimentosChildDefaults => recebimentosChildDefaultsAmbos;

  // Categorias para Pessoa Física
  static const List<Map<String, dynamic>> defaultCategoriesPF = [
    {
      'category': 'Alimentação',
      'subcategories': [
        'Açougue',
        'Bares',
        'Delivery',
        'Lanches/Café',
        'Padaria',
        'Restaurantes',
        'Supermercado',
        'Outros',
      ],
    },
    {
      'category': 'Moradia/Consumo',
      'subcategories': [
        'Água',
        'Aluguel',
        'Condomínio',
        'Gás',
        'Internet',
        'IPTU e taxas',
        'Luz',
        'Manutenção/Reformas',
        'Seguro residencial',
        'Outros',
      ],
    },
    {
      'category': 'Saúde',
      'subcategories': [
        'Academia',
        'Consultas',
        'Dentista',
        'Exames',
        'Farmácia',
        'Plano de saúde',
        'Terapias',
        'Outros',
      ],
    },
    {
      'category': 'Assinaturas e Serviços Digitais',
      'subcategories': [
        'Música',
        'Nuvem (Google/Apple/MS)',
        'Streaming',
        'Outros',
      ],
    },
    {
      'category': 'Lazer/Viagens',
      'subcategories': [
        'Cinema',
        'Hobbies',
        'Lanches/Café',
        'Presentes',
        'Restaurantes',
        'Shows',
        'Viagens',
        'Outros',
      ],
    },
    {
      'category': 'Cartões de Crédito',
      'subcategories': [
        'AMEX',
        'ELO',
        'MASTERCARD',
        'VISA',
      ],
    },
    {
      'category': 'Veículo',
      'subcategories': [
        'Combustível',
        'Estacionamento',
        'IPVA/Licenciamento',
        'Manutenções/Reparos',
        'Multas',
        'Seguro',
        'Uber',
        'Outros',
      ],
    },
    {
      'category': 'Educação',
      'subcategories': [
        'Cursos',
        'Escola/Faculdade',
        'Idiomas',
        'Livros/Materiais',
        'Outros',
      ],
    },
    {
      'category': 'Dívidas',
      'subcategories': [
        'Acordos/Renegociações',
        'Consórcio',
        'Empréstimo',
        'Financiamento imobiliário',
        'Financiamento veículo',
        'Outros',
      ],
    },
    {
      'category': 'Família e Pets',
      'subcategories': [
        'Despesas com filhos',
        'Despesas com pets',
        'Outros',
      ],
    },
    {
      'category': recebimentosName,
      'subcategories': [
        'Salário/Pró-Labore',
        'Aposentadoria/Benefícios',
        'Outras Receitas',
        'Presentes/Doações',
        'Reembolsos e Restituições',
        'Rendas de Aluguel',
        'Receitas Financeiras',
        'Trabalho Autônomo',
      ],
    },
  ];

  // Categorias para Pessoa Jurídica
  static const List<Map<String, dynamic>> defaultCategoriesPJ = [
    {
      'category': 'Despesas Operacionais',
      'subcategories': [
        'Água',
        'Aluguel',
        'Condomínio',
        'Energia elétrica',
        'Internet',
        'Limpeza',
        'Manutenção',
        'Material de consumo',
        'Material de escritório',
        'Telefone',
        'Outros',
      ],
    },
    {
      'category': 'Pessoal',
      'subcategories': [
        'FGTS',
        'INSS',
        'Pró-labore',
        'Rescisões',
        'Salários',
        'Vale-refeição',
        'Vale-transporte',
        'Outros',
      ],
    },
    {
      'category': 'Impostos e Tributos',
      'subcategories': [
        'DAS',
        'ISS',
        'Simples Nacional',
        'Taxas estaduais',
        'Taxas municipais',
        'Outros',
      ],
    },
    {
      'category': 'Financeiras',
      'subcategories': [
        'Antecipação de recebíveis',
        'Juros bancários',
        'Tarifa de cartão (crédito)',
        'Tarifa de cartão (débito)',
        'Tarifas bancárias',
        'Outros',
      ],
    },
    {
      'category': 'Fornecedores',
      'subcategories': [
        'Compra de insumos',
        'Compra de mercadorias',
        'Fornecedor A',
        'Fornecedor B',
        'Outros',
      ],
    },
    {
      'category': 'Comunicação',
      'subcategories': [
        'Celular',
        'Internet comercial',
        'Internet residencial',
        'Outros',
      ],
    },
    {
      'category': 'Tecnologia',
      'subcategories': [
        'Assinaturas (Adobe, Microsoft, etc.)',
        'Cloud / Servidores',
        'Computadores',
        'Software',
        'Outros',
      ],
    },
    {
      'category': 'Financeiro Geral',
      'subcategories': [
        'IOF',
        'Juros',
        'Multas',
        'Tarifas bancárias',
        'Outros',
      ],
    },
    {
      'category': recebimentosName,
      'subcategories': [
        'Vendas',
        'Serviços',
        'Recebimentos Financeiros',
        'Reembolsos e Ajustes',
        'Vendas de Ativos',
      ],
    },
  ];

  // Categorias para Ambos (PF e PJ)
  static const List<Map<String, dynamic>> defaultCategoriesAmbos = [
    {
      'category': 'Alimentação',
      'subcategories': [
        'Açougue',
        'Bares',
        'Delivery',
        'Lanches/Café',
        'Padaria',
        'Restaurantes',
        'Supermercado',
        'Outros',
      ],
    },
    {
      'category': 'Assinaturas e Serviços Digitais',
      'subcategories': [
        'Música',
        'Nuvem (Google/Apple/Microsoft)',
        'Software',
        'Streaming',
        'Outros',
      ],
    },
    {
      'category': 'Cartões de Crédito',
      'subcategories': [
        'AMEX',
        'ELO',
        'MASTERCARD',
        'VISA',
      ],
    },
    {
      'category': 'Comunicação',
      'subcategories': [
        'Celular',
        'Internet comercial',
        'Internet residencial',
        'Telefone',
        'Outros',
      ],
    },
    {
      'category': 'Despesas Operacionais / Moradia',
      'subcategories': [
        'Água',
        'Aluguel',
        'Condomínio',
        'Energia elétrica',
        'Gás',
        'Internet',
        'Limpeza',
        'Manutenção/Reformas',
        'Material de consumo',
        'Material de escritório',
        'Seguro residencial',
        'Outros',
      ],
    },
    {
      'category': 'Dívidas e Obrigações Financeiras',
      'subcategories': [
        'Acordos/Renegociações',
        'Consórcio',
        'Empréstimo',
        'Financiamento imobiliário',
        'Financiamento veículo',
        'Outros',
      ],
    },
    {
      'category': 'Educação',
      'subcategories': [
        'Cursos',
        'Escola/Faculdade',
        'Idiomas',
        'Livros/Materiais',
        'Outros',
      ],
    },
    {
      'category': 'Família e Pets',
      'subcategories': [
        'Despesas com filhos',
        'Despesas com pets',
        'Outros',
      ],
    },
    {
      'category': 'Financeiro Geral',
      'subcategories': [
        'Antecipação de recebíveis',
        'IOF',
        'Juros',
        'Juros bancários',
        'Multas',
        'Tarifas bancárias',
        'Outros',
      ],
    },
    {
      'category': 'Fornecedores',
      'subcategories': [
        'Compra de insumos',
        'Compra de mercadorias',
        'Fornecedor A',
        'Fornecedor B',
        'Outros',
      ],
    },
    {
      'category': 'Impostos e Tributos',
      'subcategories': [
        'DAS',
        'FGTS',
        'INSS',
        'ISS',
        'IPTU e taxas',
        'Simples Nacional',
        'Taxas estaduais',
        'Taxas municipais',
        'Outros',
      ],
    },
    {
      'category': 'Lazer e Viagens',
      'subcategories': [
        'Cinema',
        'Shows',
        'Viagens',
        'Outros',
      ],
    },
    {
      'category': 'Pessoal',
      'subcategories': [
        'Pró-labore',
        'Rescisões',
        'Salários',
        'Vale-refeição',
        'Vale-transporte',
        'Outros',
      ],
    },
    {
      'category': 'Saúde',
      'subcategories': [
        'Academia',
        'Consultas',
        'Dentista',
        'Exames',
        'Farmácia',
        'Plano de saúde',
        'Terapias',
        'Outros',
      ],
    },
    {
      'category': 'Tecnologia',
      'subcategories': [
        'Assinaturas corporativas',
        'Cloud / Servidores',
        'Computadores',
        'Software',
        'Outros',
      ],
    },
    {
      'category': 'Veículo',
      'subcategories': [
        'Combustível',
        'Estacionamento',
        'IPVA/Licenciamento',
        'Manutenções/Reparos',
        'Multas',
        'Seguro',
        'Uber',
        'Outros',
      ],
    },
    {
      'category': recebimentosName,
      'subcategories': [
        'Vendas',
        'Serviços',
        'Salário/Pró-Labore',
        'Aposentadoria/Benefícios',
        'Outras Receitas',
        'Presentes/Doações',
        'Rendas de Aluguel',
        'Receitas Financeiras',
        'Trabalho Autônomo',
        'Reembolsos e Ajustes',
        'Vendas de Ativos',
      ],
    },
  ];

  List<DefaultAccountCategory> getDefaultCategories({String tipoPessoa = 'Ambos (PF e PJ)'}) {
    final categories = _getCategoriesForTipo(tipoPessoa);
    return categories
        .map((item) => DefaultAccountCategory(
              category: item['category'] as String,
              subcategories:
                  List<String>.from(item['subcategories'] as List<dynamic>),
            ))
        .toList();
  }

  Map<String, List<String>> getCategoriesAsMap({String tipoPessoa = 'Ambos (PF e PJ)'}) {
    final categories = _getCategoriesForTipo(tipoPessoa);
    final map = <String, List<String>>{};
    for (final item in categories) {
      map[item['category'] as String] =
          List<String>.from(item['subcategories'] as List<dynamic>);
    }
    return map;
  }

  Map<String, List<String>> getRecebimentosChildDefaults({String tipoPessoa = 'Ambos (PF e PJ)'}) {
    switch (tipoPessoa) {
      case 'Pessoa Física':
        return recebimentosChildDefaultsPF;
      case 'Pessoa Jurídica':
        return recebimentosChildDefaultsPJ;
      case 'Ambos (PF e PJ)':
      default:
        return recebimentosChildDefaultsAmbos;
    }
  }

  List<Map<String, dynamic>> _getCategoriesForTipo(String tipoPessoa) {
    switch (tipoPessoa) {
      case 'Pessoa Física':
        return defaultCategoriesPF;
      case 'Pessoa Jurídica':
        return defaultCategoriesPJ;
      case 'Ambos (PF e PJ)':
      default:
        return defaultCategoriesAmbos;
    }
  }

  String buildRecebimentosChildName(String parent, String child) {
    return '$parent$recebimentosChildSeparator$child';
  }
}
