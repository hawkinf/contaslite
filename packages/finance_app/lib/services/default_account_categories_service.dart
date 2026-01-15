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

  // Mapa de ícones/emojis para as categorias pai
  static const Map<String, String> categoryLogos = {
    'Alimentação': '🍔',
    'Moradia/Consumo': '🏠',
    'Saúde': '🏥',
    'Assinaturas e Serviços Digitais': '📱',
    'Lazer/Viagens': '✈️',
    'Lazer e Viagens': '✈️',
    'Cartões de Crédito': '💳',
    'Veículo': '🚗',
    'Educação': '📚',
    'Dívidas': '💰',
    'Dívidas e Obrigações Financeiras': '💰',
    'Família e Pets': '👨‍👩‍👧‍👦',
    'Recebimentos': '💵',
    'Despesas Operacionais': '🏢',
    'Despesas Operacionais / Moradia': '🏢',
    'Pessoal': '👥',
    'Impostos e Tributos': '📄',
    'Financeiras': '🏦',
    'Financeiro Geral': '🏦',
    'Fornecedores': '📦',
    'Comunicação': '📞',
    'Tecnologia': '💻',
  };

  // =====================================================================
  // MAPA COMPLETO DE ÍCONES PARA SUBCATEGORIAS
  // Organizados por categoria pai para garantir unicidade dentro de cada grupo
  // =====================================================================

  // Alimentação - ícones únicos
  static const Map<String, String> alimentacaoLogos = {
    'Açougue': '🥩',
    'Bares': '🍺',
    'Delivery': '🛵',
    'Lanches/Café': '☕',
    'Padaria': '🥖',
    'Restaurantes': '🍽️',
    'Supermercado': '🛒',
    'Outros': '🍴',
  };

  // Moradia/Consumo - ícones únicos
  static const Map<String, String> moradiaLogos = {
    'Água': '💧',
    'Aluguel': '🏠',
    'Condomínio': '🏢',
    'Gás': '🔥',
    'Internet': '🌐',
    'IPTU e taxas': '📋',
    'Luz': '💡',
    'Manutenção/Reformas': '🔧',
    'Seguro residencial': '🛡️',
    'Outros': '🏡',
  };

  // Saúde - ícones únicos
  static const Map<String, String> saudeLogos = {
    'Academia': '🏋️',
    'Consultas': '👨‍⚕️',
    'Dentista': '🦷',
    'Exames': '🔬',
    'Farmácia': '💊',
    'Plano de saúde': '🏥',
    'Terapias': '🧘',
    'Outros': '⚕️',
  };

  // Assinaturas e Serviços Digitais - ícones únicos
  static const Map<String, String> assinaturasLogos = {
    'Música': '🎵',
    'Nuvem (Google/Apple/MS)': '☁️',
    'Nuvem (Google/Apple/Microsoft)': '☁️', // Mesmo ícone para variantes do mesmo nome
    'Streaming': '📺',
    'Software': '💿',
    'Outros': '📲',
  };

  // Lazer/Viagens - ícones únicos
  static const Map<String, String> lazerLogos = {
    'Cinema': '🎬',
    'Hobbies': '🎨',
    'Lanches/Café': '🍿',
    'Presentes': '🎁',
    'Restaurantes': '🍷',
    'Shows': '🎤',
    'Viagens': '✈️',
    'Outros': '🎭',
  };

  // Cartões de Crédito - sem ícones (os badges corretos são exibidos em buildCardBrandBadge)
  static const Map<String, String> cartoesLogos = {};

  // Veículo - ícones únicos
  static const Map<String, String> veiculoLogos = {
    'Combustível': '⛽',
    'Estacionamento': '🅿️',
    'IPVA/Licenciamento': '📄',
    'Manutenções/Reparos': '🔩',
    'Multas': '🚨',
    'Seguro': '🛡️',
    'Uber': '🚕',
    'Outros': '🚗',
  };

  // Educação - ícones únicos
  static const Map<String, String> educacaoLogos = {
    'Cursos': '🎓',
    'Escola/Faculdade': '🏫',
    'Idiomas': '🌍',
    'Livros/Materiais': '📚',
    'Outros': '📝',
  };

  // Dívidas - ícones únicos
  static const Map<String, String> dividasLogos = {
    'Acordos/Renegociações': '🤝',
    'Consórcio': '🏆',
    'Empréstimo': '🏦',
    'Financiamento imobiliário': '🏠',
    'Financiamento veículo': '🚙',
    'Outros': '💳',
  };

  // Família e Pets - ícones únicos
  static const Map<String, String> familiaLogos = {
    'Despesas com filhos': '👶',
    'Despesas com pets': '🐾',
    'Outros': '👨‍👩‍👧',
  };

  // Despesas Operacionais (PJ) - ícones únicos
  static const Map<String, String> despesasOperacionaisLogos = {
    'Água': '💧',
    'Aluguel': '🏢',
    'Condomínio': '🏬',
    'Energia elétrica': '⚡',
    'Internet': '🌐',
    'Limpeza': '🧹',
    'Manutenção': '🔧',
    'Material de consumo': '📦',
    'Material de escritório': '📎',
    'Telefone': '📞',
    'Gás': '🔥',
    'Manutenção/Reformas': '🛠️',
    'Seguro residencial': '🛡️',
    'Outros': '🏠',
  };

  // Pessoal (PJ) - ícones únicos
  static const Map<String, String> pessoalLogos = {
    'FGTS': '📊',
    'INSS': '🏛️',
    'Pró-labore': '💼',
    'Rescisões': '📝',
    'Salários': '💵',
    'Vale-refeição': '🍽️',
    'Vale-transporte': '🚌',
    'Outros': '👥',
  };

  // Impostos e Tributos - ícones únicos
  static const Map<String, String> impostosLogos = {
    'DAS': '📑',
    'ISS': '🏙️',
    'Simples Nacional': '📋',
    'Taxas estaduais': '🏛️',
    'Taxas municipais': '🏘️',
    'FGTS': '📊',
    'INSS': '🏦',
    'IPTU e taxas': '🏠',
    'Outros': '📄',
  };

  // Financeiras (PJ) - ícones únicos
  static const Map<String, String> financeirasLogos = {
    'Antecipação de recebíveis': '⏩',
    'Juros bancários': '📈',
    'Tarifa de cartão (crédito)': '💳',
    'Tarifa de cartão (débito)': '🏧',
    'Tarifas bancárias': '🏦',
    'Outros': '💰',
  };

  // Fornecedores - ícones únicos
  static const Map<String, String> fornecedoresLogos = {
    'Compra de insumos': '🧪',
    'Compra de mercadorias': '📦',
    'Fornecedor A': '🏭',
    'Fornecedor B': '🏗️',
    'Outros': '🚚',
  };

  // Comunicação - ícones únicos
  static const Map<String, String> comunicacaoLogos = {
    'Celular': '📱',
    'Internet comercial': '🌐',
    'Internet residencial': '📡',
    'Telefone': '☎️',
    'Outros': '📞',
  };

  // Tecnologia - ícones únicos
  static const Map<String, String> tecnologiaLogos = {
    'Assinaturas (Adobe, Microsoft, etc.)': '💿',
    'Assinaturas corporativas': '🔐',
    'Cloud / Servidores': '☁️',
    'Computadores': '🖥️',
    'Software': '💾',
    'Outros': '💻',
  };

  // Financeiro Geral - ícones únicos
  static const Map<String, String> financeiroGeralLogos = {
    'IOF': '📊',
    'Juros': '📈',
    'Multas': '⚠️',
    'Tarifas bancárias': '🏦',
    'Antecipação de recebíveis': '⏩',
    'Juros bancários': '💹',
    'Outros': '💰',
  };

  // =====================================================================
  // ÍCONES PARA RECEBIMENTOS (PAI E FILHO)
  // =====================================================================

  // Subcategorias pai de Recebimentos - ícones únicos
  static const Map<String, String> recebimentosPaiLogos = {
    'Salário/Pró-Labore': '💼',
    'Aposentadoria/Benefícios': '🏛️',
    'Outras Receitas': '💎',
    'Presentes/Doações': '🎁',
    'Reembolsos e Restituições': '↩️',
    'Reembolsos e Ajustes': '🔄',
    'Rendas de Aluguel': '🏠',
    'Receitas Financeiras': '📈',
    'Recebimentos Financeiros': '💹',
    'Trabalho Autônomo': '👤',
    'Vendas': '🛒',
    'Serviços': '🔧',
    'Vendas de Ativos': '🏷️',
  };

  // Salário/Pró-Labore filhos - ícones únicos
  static const Map<String, String> salarioFilhosLogos = {
    '13º Salário': '🎄',
    'Abono de Férias': '🏖️',
    'Adiantamento Salarial': '⏩',
    'Bônus': '🎯',
    'Férias': '✈️',
    'PLR': '📊',
    'Pró-labore': '💼',
    'Pró-Labore': '💼',
    'Salário Mensal': '💵',
    'Outros': '💰',
  };

  // Aposentadoria/Benefícios filhos - ícones únicos
  static const Map<String, String> aposentadoriaFilhosLogos = {
    'Auxílios': '🆘',
    'INSS': '🏛️',
    'Pensão': '👨‍👩‍👧',
    'Previdência Privada': '🛡️',
    'Outros': '📋',
  };

  // Outras Receitas filhos - ícones únicos
  static const Map<String, String> outrasReceitasFilhosLogos = {
    'Ajustes Positivos': '✅',
    'Ganhos Eventuais': '🎲',
    'Indenizações': '⚖️',
    'Restituições': '📄',
    'Venda de Bens': '💎',
    'Outros': '💫',
  };

  // Presentes/Doações filhos - ícones únicos
  static const Map<String, String> presentesFilhosLogos = {
    'Ajuda Familiar': '👨‍👩‍👧‍👦',
    'Doações': '❤️',
    'Herança': '📜',
    'Mesada': '🪙',
    'Premiações': '🏆',
    'Presentes/Doações': '🎁',
    'Outros': '🎀',
  };

  // Reembolsos e Restituições filhos - ícones únicos
  static const Map<String, String> reembolsosFilhosLogos = {
    'Ajustes': '⚙️',
    'Ajustes Positivos': '✅',
    'Ajustes/Acertos': '🔧',
    'Devoluções': '📦',
    'Estornos': '❌',
    'Estornos recebidos': '🔙',
    'Médico': '⚕️',
    'Trabalho': '💼',
    'Viagem': '✈️',
    'Reembolso (empresa)': '🏢',
    'Reembolso (saúde)': '🏥',
    'Reembolsos/Ressarcimentos': '💸',
    'Restituição IRPF': '🦁',
    'Outros': '↩️',
  };

  // Rendas de Aluguel filhos - ícones únicos
  static const Map<String, String> aluguelFilhosLogos = {
    'Arrendamento': '🌾',
    'Comercial': '🏬',
    'Equipamentos': '⚙️',
    'Garagem': '🅿️',
    'Residencial': '🏘️',
    'Outros': '🏠',
  };

  // Receitas Financeiras filhos - ícones únicos
  static const Map<String, String> receitasFinanceirasFilhosLogos = {
    'Cashback': '💵',
    'Dividendos': '📊',
    'Juros recebidos': '🏦',
    'Rendimentos (aplicações)': '📈',
    'Outros': '💹',
  };

  // Trabalho Autônomo filhos - ícones únicos
  static const Map<String, String> autonomoFilhosLogos = {
    'Bicos': '💪',
    'Comissões': '📈',
    'Consultorias': '💡',
    'Diárias': '📅',
    'Freelance': '💻',
    'Honorários': '⚖️',
    'Serviços Eventuais': '🔨',
    'Outros': '👤',
  };

  // Vendas (PJ) filhos - ícones únicos
  static const Map<String, String> vendasFilhosLogos = {
    'Marketplace': '🏪',
    'Venda à vista (PIX/dinheiro)': '💵',
    'Vendas com cartão': '💳',
    'Outros': '🛒',
  };

  // Serviços (PJ) filhos - ícones únicos
  static const Map<String, String> servicosFilhosLogos = {
    'Consultoria': '💡',
    'Contrato mensal (recorrente)': '📋',
    'Instalação/Projeto': '🔨',
    'Manutenção': '🔧',
    'Serviço avulso': '⚡',
    'Suporte': '🆘',
    'Outros': '🔩',
  };

  // Vendas de Ativos filhos - ícones únicos
  static const Map<String, String> ativosFilhosLogos = {
    'Venda de ativo (equipamento/usado)': '🏷️',
    'Outros': '💼',
  };

  /// Método principal para obter logo de uma subcategoria
  /// Recebe o nome da categoria pai e da subcategoria
  static String getLogoForSubcategoryInCategory(String categoryName, String subcategoryName) {
    // Normaliza o nome da subcategoria
    final normalizedSub = subcategoryName.trim();

    // Busca no mapa específico da categoria
    final categoryMap = _getCategorySubcategoryMap(categoryName);
    if (categoryMap.containsKey(normalizedSub)) {
      return categoryMap[normalizedSub]!;
    }

    // Fallback: busca por keyword parcial
    for (final entry in categoryMap.entries) {
      if (normalizedSub.toLowerCase().contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(normalizedSub.toLowerCase())) {
        return entry.value;
      }
    }

    // Último fallback
    return '📌';
  }

  /// Retorna o mapa de ícones para uma categoria específica
  static Map<String, String> _getCategorySubcategoryMap(String categoryName) {
    final normalized = categoryName.trim();

    switch (normalized) {
      case 'Alimentação':
        return alimentacaoLogos;
      case 'Moradia/Consumo':
        return moradiaLogos;
      case 'Saúde':
        return saudeLogos;
      case 'Assinaturas e Serviços Digitais':
        return assinaturasLogos;
      case 'Lazer/Viagens':
      case 'Lazer e Viagens':
        return lazerLogos;
      case 'Cartões de Crédito':
        return cartoesLogos;
      case 'Veículo':
        return veiculoLogos;
      case 'Educação':
        return educacaoLogos;
      case 'Dívidas':
      case 'Dívidas e Obrigações Financeiras':
        return dividasLogos;
      case 'Família e Pets':
        return familiaLogos;
      case 'Despesas Operacionais':
      case 'Despesas Operacionais / Moradia':
        return despesasOperacionaisLogos;
      case 'Pessoal':
        return pessoalLogos;
      case 'Impostos e Tributos':
        return impostosLogos;
      case 'Financeiras':
        return financeirasLogos;
      case 'Fornecedores':
        return fornecedoresLogos;
      case 'Comunicação':
        return comunicacaoLogos;
      case 'Tecnologia':
        return tecnologiaLogos;
      case 'Financeiro Geral':
        return financeiroGeralLogos;
      case 'Recebimentos':
        return recebimentosPaiLogos;
      default:
        return {};
    }
  }

  /// Retorna o logo para uma subcategoria pai de Recebimentos
  static String getLogoForRecebimentosPai(String parentName) {
    return recebimentosPaiLogos[parentName] ?? '💵';
  }

  /// Retorna o logo para uma subcategoria filho de Recebimentos
  static String getLogoForRecebimentosFilho(String parentName, String childName) {
    final normalized = childName.trim();

    Map<String, String> childMap;
    switch (parentName) {
      case 'Salário/Pró-Labore':
        childMap = salarioFilhosLogos;
        break;
      case 'Aposentadoria/Benefícios':
        childMap = aposentadoriaFilhosLogos;
        break;
      case 'Outras Receitas':
        childMap = outrasReceitasFilhosLogos;
        break;
      case 'Presentes/Doações':
        childMap = presentesFilhosLogos;
        break;
      case 'Reembolsos e Restituições':
      case 'Reembolsos e Ajustes':
        childMap = reembolsosFilhosLogos;
        break;
      case 'Rendas de Aluguel':
        childMap = aluguelFilhosLogos;
        break;
      case 'Receitas Financeiras':
      case 'Recebimentos Financeiros':
        childMap = receitasFinanceirasFilhosLogos;
        break;
      case 'Trabalho Autônomo':
        childMap = autonomoFilhosLogos;
        break;
      case 'Vendas':
        childMap = vendasFilhosLogos;
        break;
      case 'Serviços':
        childMap = servicosFilhosLogos;
        break;
      case 'Vendas de Ativos':
        childMap = ativosFilhosLogos;
        break;
      default:
        childMap = {};
    }

    if (childMap.containsKey(normalized)) {
      return childMap[normalized]!;
    }

    // Fallback por keyword
    for (final entry in childMap.entries) {
      if (normalized.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return '📌';
  }

  // Mapa legado mantido para compatibilidade
  static const Map<String, String> subcategoryLogos = {
    // Alimentação
    'Açougue': '🥩',
    'Padaria': '🥖',
    'Supermercado': '🛒',
    'Restaurante': '🍽️',
    'Lanche': '🍕',
    'Café': '☕',
    'Bar': '🍺',
    'Delivery': '🛵',

    // Salários e receitas
    'Salário': '💼',
    'Férias': '✈️',
    'Bônus': '🎯',
    'PLR': '📊',
    'Pró-Labore': '💼',
    'Adiantamento': '⏩',
    'Abono': '🏖️',

    // Benefícios
    'Aposentadoria': '👨‍🦳',
    'INSS': '🏛️',
    'Pensão': '👨‍👩‍👧',
    'Previdência': '🛡️',
    'Auxílio': '🆘',

    // Receitas de vendas e serviços
    'Venda': '🛒',
    'Marketplace': '🏪',
    'PIX': '💸',
    'Cartão': '💳',
    'Serviço': '🔧',
    'Consultoria': '💡',
    'Contrato': '📋',
    'Instalação': '🔨',
    'Manutenção': '🔩',
    'Suporte': '🆘',

    // Autônomo e trabalho
    'Autônomo': '👤',
    'Bicos': '💪',
    'Freelance': '💻',
    'Comissão': '📈',
    'Diária': '📅',
    'Honorário': '⚖️',

    // Aluguel e imóveis
    'Aluguel': '🏠',
    'Arrendamento': '🌾',
    'Comercial': '🏬',
    'Residencial': '🏘️',
    'Garagem': '🅿️',
    'Equipamento': '⚙️',
    'Água': '💧',
    'Luz': '💡',
    'Energia': '⚡',
    'Gás': '🔥',
    'Internet': '🌐',
    'Condomínio': '🏢',
    'IPTU': '📋',
    'Reforma': '🔧',
    'Seguro': '🛡️',

    // Saúde
    'Academia': '🏋️',
    'Consulta': '👨‍⚕️',
    'Dentista': '🦷',
    'Exame': '🔬',
    'Farmácia': '💊',
    'Plano': '🏥',
    'Terapia': '🧘',

    // Investimentos e finanças
    'Rendimento': '📈',
    'Dividendo': '📊',
    'Juros': '🏦',
    'Cashback': '💵',
    'Investimento': '📊',

    // Reembolsos e ajustes
    'Reembolso': '↩️',
    'Devolução': '📦',
    'Estorno': '❌',
    'Ajuste': '⚙️',
    'Acerto': '✅',
    'Médico': '⚕️',
    'Restituição': '📄',
    'IRPF': '🦁',
    'Indenização': '⚖️',
    'Ganho': '🎲',
    'Venda de Bens': '💎',
    'Outros': '📌',
  };

  /// Retorna o ícone/emoji apropriado para uma categoria
  static String? getLogoForCategory(String categoryName) {
    return categoryLogos[categoryName];
  }

  /// Retorna um ícone baseado em keywords na descrição da subcategoria
  static String? getLogoForSubcategory(String subcategoryName) {
    if (subcategoryName.isEmpty) return '❓';
    
    // Converter para lowercase para comparação insensível a caso
    final lowerName = subcategoryName.toLowerCase();
    
    // Procurar por keywords no mapa
    for (final entry in subcategoryLogos.entries) {
      if (lowerName.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    // Se nenhuma keyword encontrada, retornar genérico
    return '📌';
  }

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

  // =====================================================================
  // ÍCONES PARA FORMAS DE PAGAMENTO/RECEBIMENTO
  // =====================================================================

  static const Map<String, String> paymentMethodLogos = {
    // Cartões
    'Cartão de Credito': '💳',
    'Cartão de Crédito': '💳',
    'Cartão': '💳',

    // Transferências e PIX
    'PIX': '⚡',
    'Crédito em conta': '🏦',
    'Transferência': '🔄',
    'TED': '🏛️',
    'DOC': '📄',

    // Dinheiro
    'Dinheiro': '💵',
    'Espécie': '💸',
    'Cash': '💵',

    // Débito
    'Débito C/C': '🏧',
    'Débito': '🏧',
    'Cartão de Débito': '🏧',

    // Internet Banking
    'Internet Banking': '🌐',
    'Bank Online': '💻',

    // Boleto
    'Boleto': '📃',
    'Boleto Bancário': '📃',

    // Cheque
    'Cheque': '📝',
    'Cheque Pré': '📋',

    // Outros
    'Outros': '📌',
  };

  /// Retorna o ícone para uma forma de pagamento
  static String getLogoForPaymentMethod(String methodName) {
    final normalized = methodName.trim();

    // Busca direta
    if (paymentMethodLogos.containsKey(normalized)) {
      return paymentMethodLogos[normalized]!;
    }

    // Busca por keyword (case insensitive)
    final lowerName = normalized.toLowerCase();
    for (final entry in paymentMethodLogos.entries) {
      if (lowerName.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lowerName)) {
        return entry.value;
      }
    }

    // Fallback por tipo
    if (lowerName.contains('cart')) return '💳';
    if (lowerName.contains('pix')) return '⚡';
    if (lowerName.contains('dinheiro') || lowerName.contains('cash')) return '💵';
    if (lowerName.contains('débit') || lowerName.contains('debit')) return '🏧';
    if (lowerName.contains('transfer') || lowerName.contains('ted') || lowerName.contains('doc')) return '🔄';
    if (lowerName.contains('boleto')) return '📃';
    if (lowerName.contains('cheque')) return '📝';
    if (lowerName.contains('bank') || lowerName.contains('conta')) return '🏦';

    return '💰';
  }

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
