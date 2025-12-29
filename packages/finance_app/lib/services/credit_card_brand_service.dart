import 'dart:convert';
import 'package:http/http.dart' as http;

class CreditCardBrand {
  final String name;
  final String code;

  CreditCardBrand({required this.name, required this.code});

  factory CreditCardBrand.fromJson(Map<String, dynamic> json) {
    return CreditCardBrand(
      name: json['name'] ?? json['nome'] ?? '',
      code: json['code'] ?? json['codigo'] ?? '',
    );
  }
}

class CreditCardBrandService {
  static final CreditCardBrandService instance = CreditCardBrandService._();
  CreditCardBrandService._();

  List<CreditCardBrand>? _cache;
  DateTime? _cacheTime;

  // Bandeiras padrão (fallback caso a API falhe)
  static const List<Map<String, String>> defaultBrands = [
    {'name': 'Visa', 'code': 'VISA'},
    {'name': 'Mastercard', 'code': 'MASTERCARD'},
    {'name': 'Elo', 'code': 'ELO'},
    {'name': 'American Express', 'code': 'AMEX'},
    {'name': 'Diners Club', 'code': 'DINERS'},
    {'name': 'Hipercard', 'code': 'HIPERCARD'},
    {'name': 'Discover', 'code': 'DISCOVER'},
    {'name': 'Aura', 'code': 'AURA'},
  ];

  Future<List<CreditCardBrand>> fetchBrands({bool forceRefresh = false}) async {
    // Usar cache se disponível e não expirado (24 horas)
    if (_cache != null &&
        !forceRefresh &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inHours < 24) {
      return _cache!;
    }

    try {
      // Tentar buscar da API do Banco Central
      final uri = Uri.parse(
          'https://brasilapi.com.br/api/credit-cards/v1');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as List<dynamic>;
        _cache = data
            .map((e) => CreditCardBrand.fromJson(e as Map<String, dynamic>))
            .toList();
        _cacheTime = DateTime.now();
        return _cache!;
      }
    } catch (e) {
      // Silenciosamente ignorar erro e usar fallback
    }

    // Usar bandeiras padrão se API falhar
    _cache = defaultBrands
        .map((e) => CreditCardBrand(name: e['name']!, code: e['code']!))
        .toList();
    _cacheTime = DateTime.now();
    return _cache!;
  }

  // Obter bandeiras padrão sem fazer requisição
  List<CreditCardBrand> getDefaultBrands() {
    return defaultBrands
        .map((e) => CreditCardBrand(name: e['name']!, code: e['code']!))
        .toList();
  }

  // Limpar cache
  void clearCache() {
    _cache = null;
    _cacheTime = null;
  }
}
