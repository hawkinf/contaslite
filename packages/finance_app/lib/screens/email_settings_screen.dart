import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/email_settings_service.dart';

class EmailSettingsScreen extends StatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen> {
  final _emailService = EmailSettingsService.instance;
  EmailSettings? _settings;
  EmailStatus? _status;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _emailService.initialize();
      final settings = await _emailService.loadSettings();
      final status = await _emailService.checkStatus();

      if (mounted) {
        setState(() {
          _settings = settings;
          _status = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    if (_settings == null) return;

    final newSettings = _settings!.copyWith(isEnabled: value);
    final success = await _emailService.updateSettings(newSettings);

    if (success && mounted) {
      setState(() {
        _settings = _emailService.settingsNotifier.value;
      });
      _showSnackBar(value ? 'Notificações ativadas' : 'Notificações desativadas');
    } else if (mounted) {
      _showSnackBar('Erro ao atualizar configurações', isError: true);
    }
  }

  Future<void> _updateFrequency(String frequency) async {
    if (_settings == null) return;

    final newSettings = _settings!.copyWith(frequency: frequency);
    final success = await _emailService.updateSettings(newSettings);

    if (success && mounted) {
      setState(() {
        _settings = _emailService.settingsNotifier.value;
      });
      Navigator.pop(context);
    } else if (mounted) {
      _showSnackBar('Erro ao atualizar frequência', isError: true);
    }
  }

  Future<void> _updateTime(TimeOfDay time) async {
    if (_settings == null) return;

    final newSettings = _settings!.copyWith(
      sendHour: time.hour,
      sendMinute: time.minute,
    );
    final success = await _emailService.updateSettings(newSettings);

    if (success && mounted) {
      setState(() {
        _settings = _emailService.settingsNotifier.value;
      });
    } else if (mounted) {
      _showSnackBar('Erro ao atualizar horário', isError: true);
    }
  }

  Future<void> _updateWeeklyDay(int day) async {
    if (_settings == null) return;

    final newSettings = _settings!.copyWith(weeklyDay: day);
    final success = await _emailService.updateSettings(newSettings);

    if (success && mounted) {
      setState(() {
        _settings = _emailService.settingsNotifier.value;
      });
      Navigator.pop(context);
    } else if (mounted) {
      _showSnackBar('Erro ao atualizar dia da semana', isError: true);
    }
  }

  Future<void> _updateMonthlyDay(int day) async {
    if (_settings == null) return;

    final newSettings = _settings!.copyWith(monthlyDay: day);
    final success = await _emailService.updateSettings(newSettings);

    if (success && mounted) {
      setState(() {
        _settings = _emailService.settingsNotifier.value;
      });
      Navigator.pop(context);
    } else if (mounted) {
      _showSnackBar('Erro ao atualizar dia do mês', isError: true);
    }
  }

  Future<void> _sendTestEmail() async {
    final result = await _emailService.sendTestEmail();

    if (mounted) {
      _showSnackBar(result.message, isError: !result.success);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showFrequencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frequência de Envio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _frequencyOption('daily', 'Diário', 'Envio todos os dias'),
            _frequencyOption('weekly', 'Semanal', 'Envio uma vez por semana'),
            _frequencyOption('biweekly', 'Quinzenal', 'Envio a cada 2 semanas'),
            _frequencyOption('monthly', 'Mensal', 'Envio uma vez por mês'),
          ],
        ),
      ),
    );
  }

  Widget _frequencyOption(String value, String title, String subtitle) {
    final isSelected = _settings?.frequency == value;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () => _updateFrequency(value),
    );
  }

  void _showTimePickerDialog() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _settings?.sendHour ?? 3,
        minute: _settings?.sendMinute ?? 0,
      ),
      helpText: 'Selecione o horário de envio',
    );

    if (time != null) {
      await _updateTime(time);
    }
  }

  void _showWeeklyDayDialog() {
    const days = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dia da Semana'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(7, (index) {
            final isSelected = _settings?.weeklyDay == index;
            return ListTile(
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(days[index]),
              onTap: () => _updateWeeklyDay(index),
            );
          }),
        ),
      ),
    );
  }

  void _showMonthlyDayDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dia do Mês'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 28,
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = _settings?.monthlyDay == day;
              return InkWell(
                onTap: () => _updateMonthlyDay(day),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações por Email'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(user),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text(
            'Erro ao carregar configurações',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Erro desconhecido',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(dynamic user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status do serviço
        if (_status != null) _buildStatusCard(),

        const SizedBox(height: 16),

        // Email cadastrado (somente visualização)
        _buildEmailInfoCard(user?.email ?? 'Não informado'),

        const SizedBox(height: 16),

        // Ativar/Desativar
        _buildEnableCard(),

        // Botão de teste (sempre visível)
        const SizedBox(height: 16),
        _buildTestButton(),

        if (_settings?.isEnabled == true) ...[
          const SizedBox(height: 16),

          // Frequência
          _buildFrequencyCard(),

          const SizedBox(height: 16),

          // Horário
          _buildTimeCard(),

          // Dia da semana (se semanal ou quinzenal)
          if (_settings?.frequency == 'weekly' || _settings?.frequency == 'biweekly') ...[
            const SizedBox(height: 16),
            _buildWeeklyDayCard(),
          ],

          // Dia do mês (se mensal)
          if (_settings?.frequency == 'monthly') ...[
            const SizedBox(height: 16),
            _buildMonthlyDayCard(),
          ],

          const SizedBox(height: 16),

          // Info do próximo envio
          if (_settings?.nextSendAt != null) _buildNextSendInfo(),
        ],
      ],
    );
  }

  Widget _buildStatusCard() {
    final configured = _status?.configured ?? false;
    final running = _status?.schedulerRunning ?? false;

    return Card(
      color: configured && running
          ? Colors.green.shade50
          : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              configured && running ? Icons.check_circle : Icons.warning,
              color: configured && running ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    configured && running
                        ? 'Serviço de email ativo'
                        : 'Serviço de email não configurado',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    configured && running
                        ? 'Os emails serão enviados conforme agendado'
                        : 'Configure as credenciais SMTP no servidor',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailInfoCard(String email) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.email_outlined),
        title: const Text('Email cadastrado'),
        subtitle: Text(email),
        trailing: const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildEnableCard() {
    return Card(
      child: SwitchListTile(
        secondary: Icon(
          _settings?.isEnabled == true
              ? Icons.notifications_active
              : Icons.notifications_off_outlined,
          color: _settings?.isEnabled == true ? Colors.green : Colors.grey,
        ),
        title: const Text('Receber relatórios por email'),
        subtitle: Text(
          _settings?.isEnabled == true
              ? 'Você receberá relatórios de contas periodicamente'
              : 'Ative para receber relatórios de contas',
        ),
        value: _settings?.isEnabled ?? false,
        onChanged: _toggleEnabled,
      ),
    );
  }

  Widget _buildFrequencyCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.schedule),
        title: const Text('Frequência'),
        subtitle: Text(_settings?.frequencyLabel ?? 'Diário'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _showFrequencyDialog,
      ),
    );
  }

  Widget _buildTimeCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.access_time),
        title: const Text('Horário de envio'),
        subtitle: Text(_settings?.sendTimeLabel ?? '03:00'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _showTimePickerDialog,
      ),
    );
  }

  Widget _buildWeeklyDayCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today),
        title: const Text('Dia da semana'),
        subtitle: Text(_settings?.weeklyDayLabel ?? 'Segunda'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _showWeeklyDayDialog,
      ),
    );
  }

  Widget _buildMonthlyDayCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_month),
        title: const Text('Dia do mês'),
        subtitle: Text('Dia ${_settings?.monthlyDay ?? 1}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _showMonthlyDayDialog,
      ),
    );
  }

  Widget _buildTestButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _emailService.loadingNotifier,
      builder: (context, isLoading, _) {
        return ElevatedButton.icon(
          onPressed: isLoading ? null : _sendTestEmail,
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(isLoading ? 'Enviando...' : 'Enviar email de teste'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        );
      },
    );
  }

  Widget _buildNextSendInfo() {
    final nextSend = _settings?.nextSendAt;
    if (nextSend == null) return const SizedBox.shrink();

    final formatted = '${nextSend.day.toString().padLeft(2, '0')}/'
        '${nextSend.month.toString().padLeft(2, '0')}/'
        '${nextSend.year} às '
        '${nextSend.hour.toString().padLeft(2, '0')}:'
        '${nextSend.minute.toString().padLeft(2, '0')}';

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.upcoming, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Próximo envio',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    formatted,
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
