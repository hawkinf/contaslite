import 'package:flutter/material.dart';
import '../services/holiday_service.dart';

class HolidaysScreen extends StatefulWidget {
  const HolidaysScreen({super.key});

  @override
  State<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends State<HolidaysScreen> {
  late int _selectedYear;

  static const _sectionTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.indigo,
  );

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final details = HolidayService.getHolidayDetailsFormatted(_selectedYear);
    final stats = HolidayService.getHolidaysByWeekday(_selectedYear);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Seletor de Ano
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 32),
                onPressed: () {
                  setState(() => _selectedYear--);
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedYear.toString(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 32),
                onPressed: () {
                  setState(() => _selectedYear++);
                },
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Resumo por Dia da Semana - GRANDE E DESTACADO
          const Text(
            'Quantos feriados caem em cada dia',
            style: _sectionTitleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildDayChip('Seg', stats['Segunda'] ?? 0, Colors.blue),
              _buildDayChip('Ter', stats['Terça'] ?? 0, Colors.cyan),
              _buildDayChip('Qua', stats['Quarta'] ?? 0, Colors.green),
              _buildDayChip('Qui', stats['Quinta'] ?? 0, Colors.amber),
              _buildDayChip('Sex', stats['Sexta'] ?? 0, Colors.orange),
              _buildDayChip('Sab', stats['Sábado'] ?? 0, Colors.red),
              _buildDayChip('Dom', stats['Domingo'] ?? 0, Colors.purple),
            ],
          ),
          const SizedBox(height: 32),

          // Lista de Feriados
          Text(
            'Lista de Feriados de $_selectedYear',
            style: _sectionTitleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < details.length; i++) ...[
                    _buildHolidayItem(details[i]),
                    if (i < details.length - 1)
                      const Divider(
                        height: 16,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(String label, int count, Color color) {
    return Container(
      width: 70,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayItem(String detail) {
    // Extrai informações do detalhe (formato: "Nome: Dia, data")
    final parts = detail.split(': ');
    if (parts.length < 2) return Text(detail);

    final name = parts[0];
    final dateInfo = parts[1];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.indigo,
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
                const SizedBox(height: 2),
                Text(
                  dateInfo,
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
