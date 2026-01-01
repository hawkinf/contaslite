import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class RecebimentosScreen extends StatelessWidget {
  const RecebimentosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(typeNameFilter: 'Recebimentos'),
        );
      },
    );
  }
}
