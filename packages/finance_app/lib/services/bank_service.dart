import 'dart:convert';
import 'package:http/http.dart' as http;

class BankInfo {
  final int code;
  final String name;
  BankInfo({required this.code, required this.name});

  @override
  String toString() => '${code.toString().padLeft(3, '0')} - $name';
}

class BankService {
  static final BankService instance = BankService._();
  BankService._();

  List<BankInfo>? _cache;

  Future<List<BankInfo>> fetchBanks() async {
    if (_cache != null && _cache!.isNotEmpty) return _cache!;
    final uri = Uri.parse('https://brasilapi.com.br/api/banks/v1');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Erro ao carregar bancos (${resp.statusCode})');
    }
    final data = json.decode(resp.body) as List<dynamic>;
    _cache = data
        .map((e) => BankInfo(
              code: e['code'] is int ? e['code'] as int : int.tryParse('${e['code']}') ?? 0,
              name: e['name'] ?? '',
            ))
        .where((b) => b.code != 0 && b.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return _cache!;
  }
}
