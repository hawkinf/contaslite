/// Configuração do Google Sign-In
///
/// IMPORTANTE: Substitua o valor abaixo pelo seu Client ID real
/// obtido no Google Cloud Console (tipo: Web Application)
///
/// Para obter o Client ID:
/// 1. Acesse https://console.cloud.google.com/apis/credentials
/// 2. Crie um projeto ou selecione um existente
/// 3. Crie uma credencial OAuth 2.0 do tipo "Web Application"
/// 4. Copie o Client ID e cole abaixo
class GoogleAuthConfig {
  /// Client ID do Google (tipo Web Application)
  /// Este mesmo ID é usado no backend para validar os tokens
  ///
  /// Exemplo: 123456789-abcdefgh.apps.googleusercontent.com
  static const String webClientId =
      '733489428773-rse8acmbhf2rgbjioteiss4jg5lhqf11.apps.googleusercontent.com';

  /// Client Secret do Google (necessário para troca de código por tokens no Windows)
  /// NOTA: Em aplicativos móveis/web normalmente não se usa client_secret,
  /// mas para OAuth desktop flow com localhost redirect é necessário.
  static const String webClientSecret = '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';

  /// Verifica se o Client ID foi configurado
  static bool get isConfigured =>
      webClientId != 'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com' &&
      webClientId.contains('.apps.googleusercontent.com');
}
