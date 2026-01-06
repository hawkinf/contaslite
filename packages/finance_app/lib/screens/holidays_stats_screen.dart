import 'package:flutter/material.dart';
import '../services/holiday_service.dart';

class HolidaysStatsScreen extends StatefulWidget {
  const HolidaysStatsScreen({super.key});

  @override
  State<HolidaysStatsScreen> createState() => _HolidaysStatsScreenState();
}

class _HolidaysStatsScreenState extends State<HolidaysStatsScreen> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final analysis = HolidayService.getHolidayAnalysis(_selectedYear);
    final byWeekday = analysis['by_weekday'] as Map<String, int>;
    final details = analysis['details'] as List<String>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas de Feriados'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Seletor de Ano
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecione o Ano',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _selectedYear--);
                          },
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Anterior'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            _selectedYear.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _selectedYear++);
                          },
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Próximo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Título da Seção
          Text(
            'Resumo por Dia da Semana',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          // Cards com Estatísticas por Dia
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              _buildDayCard('Segunda', byWeekday['Segunda'] ?? 0, Colors.blue),
              _buildDayCard('Terça', byWeekday['Terça'] ?? 0, Colors.cyan),
              _buildDayCard('Quarta', byWeekday['Quarta'] ?? 0, Colors.green),
              _buildDayCard('Quinta', byWeekday['Quinta'] ?? 0, Colors.amber),
              _buildDayCard('Sexta', byWeekday['Sexta'] ?? 0, Colors.orange),
              _buildDayCard('Sábado', byWeekday['Sábado'] ?? 0, Colors.red),
              _buildDayCard('Domingo', byWeekday['Domingo'] ?? 0, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          // Total de Feriados
          Card(
            color: Colors.blue.shade50,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total de Feriados',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${byWeekday.values.reduce((a, b) => a + b)} dias',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.event,
                    size: 48,
                    color: Colors.blue.shade300,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Título da Seção de Detalhes
          Text(
            'Feriados Detalhados',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          // Lista de Feriados
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < details.length; i++) ...[
                    _buildHolidayDetail(details[i], i),
                    if (i < details.length - 1)
                      Divider(
                        color: Colors.grey.shade300,
                        height: 24,
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDayCard(String day, int count, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'feriado${count > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHolidayDetail(String detail, int index) {
    // Extrai o dia da semana da string "Nome: Dia, data"
    final parts = detail.split(': ');
    if (parts.length < 2) return Text(detail);

    final name = parts[0];
    final dayAndDate = parts[1];
    final dayParts = dayAndDate.split(',');
    final day = dayParts.isNotEmpty ? dayParts[0] : '';
    final date = dayParts.length > 1 ? dayParts[1].trim() : '';

    // Cores para diferentes dias
    final colors = [
      Colors.blue,
      Colors.cyan,
      Colors.green,
      Colors.amber,
      Colors.orange,
      Colors.red,
      Colors.purple,
    ];
    final color = colors[index % colors.length];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$day, $date',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
