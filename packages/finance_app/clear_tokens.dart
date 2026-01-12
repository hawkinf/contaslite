// ignore_for_file: avoid_print

import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Listar todas as chaves
  print('Chaves armazenadas:');
  for (final key in prefs.getKeys()) {
    print('  $key');
  }
  
  // Remover tokens para forçar novo login
  await prefs.remove('accessToken');
  await prefs.remove('refreshToken');
  await prefs.remove('expiresAt');
  await prefs.remove('refreshExpiresAt');
  await prefs.remove('userId');
  await prefs.remove('userEmail');
  await prefs.remove('userName');
  
  print('\nTokens removidos com sucesso!');
  print('Na próxima execução, você verá a tela de Login.');
}
