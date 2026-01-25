import 'package:flutter/material.dart';
import '../services/database_migration_service.dart';

class DatabaseMigrationScreen extends StatefulWidget {
  const DatabaseMigrationScreen({super.key});

  @override
  State<DatabaseMigrationScreen> createState() =>
      _DatabaseMigrationScreenState();
}

class _DatabaseMigrationScreenState extends State<DatabaseMigrationScreen> {
  late Future<void> migrationFuture;

  @override
  void initState() {
    super.initState();
    migrationFuture = _startMigration();
  }

  Future<void> _startMigration() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await DatabaseMigrationService.instance.performMigration();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: migrationFuture,
        builder: (context, snapshot) {
          return Center(
            child: ValueListenableBuilder<MigrationStatus>(
              valueListenable:
                  DatabaseMigrationService.instance.migrationStatus,
              builder: (context, status, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ícone com animação
                    _buildAnimatedIcon(status),
                    const SizedBox(height: 32),

                    // Título
                    Text(
                      status.isError
                          ? '⚠️ Erro na Migração'
                          : status.isCompleted
                              ? '✅ Sucesso!'
                              : '🔄 Atualizando Banco de Dados',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Mensagem
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        status.message,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Progress bar
                    if (!status.isError && !status.isCompleted)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: status.progress,
                                minHeight: 8,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${(status.progress * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),

                    // Informações adicionais
                    if (status.isCompleted)
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Continuar'),
                            ),
                          ],
                        ),
                      ),

                    // Botão de erro
                    if (status.isError)
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Column(
                          children: [
                            Text(
                              'Por favor, contacte o suporte se o problema persistir.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Fechar'),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedIcon(MigrationStatus status) {
    if (status.isError) {
      return const Icon(
        Icons.error_outline,
        size: 64,
        color: Colors.red,
      );
    }

    if (status.isCompleted) {
      return const Icon(
        Icons.check_circle_outline,
        size: 64,
        color: Colors.green,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      onEnd: () {
        setState(() {});
      },
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value * 6.28,
          child: Icon(
            Icons.sync,
            size: 64,
            color: Colors.blue.shade600,
          ),
        );
      },
    );
  }
}
