import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/prefs_service.dart';
import '../services/secure_credential_storage.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _rememberCredentials = false;

  @override
  void initState() {
    super.initState();
    // Observar mudanças no estado de autenticação
    AuthService.instance.authStateNotifier.addListener(_onAuthStateChanged);
    _prefillSavedCredentials();
  }

  Future<void> _prefillSavedCredentials() async {
    final saved = await SecureCredentialStorage.loadSavedCredentials();
    if (saved != null && mounted) {
      setState(() {
        _emailController.text = saved.email;
        _passwordController.text = saved.password;
        _rememberCredentials = true;
      });
    }
  }

  @override
  void dispose() {
    AuthService.instance.authStateNotifier.removeListener(_onAuthStateChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onAuthStateChanged() {
    final authState = AuthService.instance.authStateNotifier.value;
    debugPrint('🏠 [LoginScreen] AuthState mudou para: $authState');
    
    // Se foi autenticado, fechar a tela de login
    if (authState == AuthState.authenticated && mounted) {
      debugPrint('🏠 [LoginScreen] Usuario autenticado, fechando tela de login');
      // Pop LoginScreen para voltar ao FinanceApp que renderizará HomeScreen
      Navigator.of(context).pop();
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Recarregar configuração da API antes de tentar login
    final config = await PrefsService.loadDatabaseConfig();
    if (config.apiUrl != null && config.apiUrl!.isNotEmpty) {
      AuthService.instance.setApiUrl(config.apiUrl!);
    }

    debugPrint('🏠 [LoginScreen] Iniciando login...');
    final result = await AuthService.instance.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    debugPrint('🏠 [LoginScreen] Login retornou: success=${result.success}');

    if (!mounted) return;

    if (result.success) {
      if (_rememberCredentials) {
        await SecureCredentialStorage.saveCredentials(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await SecureCredentialStorage.clearSavedCredentials();
      }
      // Não precisa fazer navigator aqui - _onAuthStateChanged vai cuidar disso
      debugPrint('✅ Login bem-sucedido, aguardando redirecionamento...');
      // Manter _isLoading = true para bloquear interações
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error;
      });
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      // Inicializar o serviço se necessário
      await GoogleAuthService.instance.initialize();

      // Fazer login com Google
      final result = await GoogleAuthService.instance.signInWithGoogle();

      if (!mounted) return;

      if (result.success) {
        debugPrint('✅ Login com Google bem-sucedido');
        // O redirecionamento será feito pelo _onAuthStateChanged
      } else {
        setState(() {
          _isGoogleLoading = false;
          if (result.errorCode != 'CANCELLED') {
            _errorMessage = result.error;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGoogleLoading = false;
        _errorMessage = 'Erro ao fazer login com Google: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Voltar',
        ),
        title: const Text('Contas Lite'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo e Título
                    Icon(
                      Icons.account_balance_wallet,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Contas Lite',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entre na sua conta para sincronizar seus dados',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Mensagem de erro
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Campo Email
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'seu@email.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, informe seu email';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Por favor, informe um email válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Campo Senha
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        hintText: 'Sua senha',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      enabled: !_isLoading,
                      onFieldSubmitted: (_) => _login(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, informe sua senha';
                        }
                        if (value.length < 6) {
                          return 'A senha deve ter pelo menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Salvar credenciais
                    CheckboxListTile(
                      value: _rememberCredentials,
                      onChanged: _isLoading
                          ? null
                          : (val) => setState(() => _rememberCredentials = val ?? true),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Salvar as credenciais'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),

                    // Botão Login
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Entrar',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Link para cadastro
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Não tem conta? ',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _goToRegister,
                          child: const Text('Cadastre-se'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Divisor
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[400])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'ou',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[400])),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botão Google Sign-In
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: (_isLoading || _isGoogleLoading)
                            ? null
                            : _loginWithGoogle,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.grey[400]!,
                          ),
                        ),
                        icon: _isGoogleLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const _GoogleLogo(size: 20),
                        label: Text(
                          _isGoogleLoading
                              ? 'Conectando...'
                              : 'Continuar com Google',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Aviso sobre modo offline
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No modo offline, seus dados ficam apenas neste dispositivo.',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget que desenha o logo oficial do Google com as 4 cores
class _GoogleLogo extends StatelessWidget {
  final double size;

  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double centerX = s / 2;
    final double centerY = s / 2;
    final double radius = s * 0.45;
    final double strokeWidth = s * 0.18;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Azul (direita)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      -0.4, // ~-23 graus
      1.2,  // ~69 graus
      false,
      paint,
    );

    // Verde (inferior direito)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      0.8,  // ~46 graus
      1.2,  // ~69 graus
      false,
      paint,
    );

    // Amarelo (inferior esquerdo)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      2.0,  // ~115 graus
      1.0,  // ~57 graus
      false,
      paint,
    );

    // Vermelho (superior)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      3.0,  // ~172 graus
      1.8,  // ~103 graus (até o topo)
      false,
      paint,
    );

    // Barra horizontal azul do G
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        centerX - strokeWidth * 0.1,
        centerY - strokeWidth / 2,
        radius + strokeWidth / 2,
        strokeWidth,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
