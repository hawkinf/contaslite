# Copilot instructions

## Visão geral da arquitetura
- O fluxo de entrada em lib/main.dart inicializa o tamanho da janela (desktop), o locale/formatação e renderiza a UI principal de feriados/calendário com abas embutidas do módulo financeiro.
- O módulo financeiro fica dentro de packages/finance_app e sua camada de abas mantém as telas de finanças vivas por meio de um IndexedStack; PrefsService.tabRequestNotifier dirige as trocas programáticas de aba.

## Serviços e fluxo de dados
- PrefsService (packages/finance_app/lib/services/prefs_service.dart) é a fonte única de verdade para tema, seleção de região/cidade, intervalo de datas, solicitações de aba e preferências de proteção do banco; cada setter deve persistir no SharedPreferences e publicar atualizações pelo ValueNotifier associado (themeNotifier, cityNotifier, dateRangeNotifier, tabRequestNotifier, autoBackupEnabled).
- DatabaseHelper (packages/finance_app/lib/database/db_helper.dart) declara finance_v62.db, configura os PRAGMAs, cria índices e mantém todos os caminhos de migração. Anexe mudanças de esquema ali e chame DatabaseProtectionService antes de executar migrações destrutivas para preservar uma cópia com checksum.
- DatabaseInitializationService injeta dados seed (categorias/subcategorias padrão e métodos de pagamento) a partir de default_account_categories_service.dart e o helper de métodos de pagamento depois que o esquema estiver pronto; reutilize esses helpers ao introduzir novos valores padrão.
- DatabaseMigrationService embrulha onUpgrade do sqflite e expõe um MigrationStatus ValueNotifier. DatabaseMigrationScreen observa esse notifier, então processos longos devem atualizá-lo antes e depois de validações pesadas.

## Padrões de UI e integração
- SettingsScreen (packages/finance_app/lib/screens/settings_screen.dart) lê PrefsService.cityNotifier e themeNotifier em initState, usa HolidayService.regions (services/holiday_service.dart) para ordenar as cidades e salva as escolhas com PrefsService.saveLocation; o diálogo de cidades mantém estado local de busca, um bom padrão para outros seletores modais.
- Ao tocar em “Banco de dados”, SettingsScreen define PrefsService.tabRequestNotifier para 6 para que o controlador de abas da HomeScreen abra a aba de banco; qualquer outro código que precise navegar por abas programaticamente deve atualizar esse mesmo notifier.
- Os logs entre serviços usam prefixos com emoji (🚀 para ciclo de vida, 🔧 para serviços, 🏠 para telas, etc.). DEBUG_GUIDE.md e DEBUG_SUMMARY.txt dependem desses marcadores, então mantenha a convenção ao adicionar diagnósticos para que o rastreador de congelamentos consiga interpretá-los.

## Backup, proteção e recuperação
- BackupService (packages/finance_app/lib/services/backup_service.dart) roda em AppLifecycleState.detached e copia o banco ativo, mantém os dez backups mais recentes e permite restaurações manuais; reaproveite seus helpers sempre que expor backups em outro lugar.
- DatabaseProtectionService grava backups em ContasLite/Backups, calcula SHA-256, registra metadados em JSON, roda uma rotação até cinco cópias e faz verificações de integridade (PRAGMA integrity_check, foreign_key_check, detecção de órfãos) antes de migrações; invoque-o antes de qualquer mudança destrutiva em db_helper ou DatabaseMigrationService.
- BackupService, DatabaseProtectionService e DatabaseHelper esperam o nome finance_v62.db na pasta de documentos do app, então evite renomeá-lo a menos que todas as referências sejam atualizadas.

## Fluxos de trabalho e depuração
- Para reproduzir o congelamento de Preferências, siga DEBUG_GUIDE.md: execute flutter run -v | Tee-Object -FilePath debug_logs.txt (PowerShell) ou flutter run -v > debug_logs.txt 2>&1 (cmd), espere os logs ricos em emoji, toque na engrenagem e pare com Ctrl+C. As últimas 50 linhas indicarão se o travamento ocorre em HomeScreen.initState ou SettingsScreen.initState, conforme mostrado em DEBUG_SUMMARY.txt.
- Mantenha flutter analyze e flutter test (que roda test/widget_test.dart e holiday_loading_test.dart) na rotina pré-commit porque analysis_options.yaml aplica lintes mais rigorosos.
- Continue usando prefixos com emoji (🚀, 🔧, 🗂️) em novos diagnósticos para que scripts de triagem automática localizem pontos importantes de log, como descrito nos guias de depuração.

## Pedido de retorno
- Avise-me se alguma parte acima estiver confusa ou faltar contexto para que eu possa atualizar essas instruções.



