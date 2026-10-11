import 'package:flutter_test/flutter_test.dart';
import 'package:visary/services/local_analyzer.dart';
import 'package:visary/services/video_service.dart';

void main() {
  group('VideoSignals & LocalAnalyzer Unit Tests', () {
    test('VideoSignals energyAt and meanEnergy return -90 for empty energy list', () {
      final signals = VideoSignals(
        shots: [0.0, 15.0, 30.0],
        energy: [],
        duration: 30.0,
      );

      expect(signals.energyAt(5.0), equals(-90));
      expect(signals.meanEnergy(0.0, 10.0), equals(-90));
      expect(signals.shotsIn(0.0, 30.0), equals(1)); // 15.0 is strictly between 0 and 30
    });

    test('VideoSignals correctly calculates mean energy and shot count', () {
      final energyPoints = <AudioEnergyPoint>[
        const AudioEnergyPoint(0.0, -20.0),
        const AudioEnergyPoint(1.0, -10.0),
        const AudioEnergyPoint(2.0, -30.0),
      ];

      final signals = VideoSignals(
        shots: [0.0, 5.0, 10.0, 15.0],
        energy: energyPoints,
        duration: 15.0,
      );

      expect(signals.energyAt(1.2), equals(-10.0));
      expect(signals.meanEnergy(0.0, 2.0), equals(-15.0)); // (-20 + -10) / 2
      expect(signals.shotsIn(1.0, 12.0), equals(2)); // 5.0 and 10.0
    });
  });
}
