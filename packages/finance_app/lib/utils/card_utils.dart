/* Utilities for credit card processing */

class CardBreakdown {
  final double total;
  final double installments;
  final double oneOff;
  final double subscriptions;

  const CardBreakdown({
    required this.total,
    required this.installments,
    required this.oneOff,
    required this.subscriptions,
  });

  factory CardBreakdown.parse(String? observation) {
    if (observation == null || !observation.startsWith('T:')) {
      return const CardBreakdown(
        total: 0,
        installments: 0,
        oneOff: 0,
        subscriptions: 0,
      );
    }

    try {
      final parts = observation.split(';');
      final total = double.parse(parts[0].split(':')[1]);
      final installments = double.parse(parts[1].split(':')[1]);
      final oneOff = double.parse(parts[2].split(':')[1]);
      final subscriptions = double.parse(parts[3].split(':')[1]);

      return CardBreakdown(
        total: total,
        installments: installments,
        oneOff: oneOff,
        subscriptions: subscriptions,
      );
    } catch (_) {
      return const CardBreakdown(
        total: 0,
        installments: 0,
        oneOff: 0,
        subscriptions: 0,
      );
    }
  }

  bool get isValid => total > 0 || installments > 0 || oneOff > 0 || subscriptions > 0;
}
