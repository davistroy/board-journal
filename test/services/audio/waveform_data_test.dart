import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/services/audio/waveform_data.dart';

void main() {
  group('WaveformData', () {
    group('constructor', () {
      test('creates with default maxSamples of 50', () {
        final waveform = WaveformData();

        expect(waveform.maxSamples, 50);
      });

      test('creates with custom maxSamples', () {
        final waveform = WaveformData(maxSamples: 100);

        expect(waveform.maxSamples, 100);
      });

      test('starts empty', () {
        final waveform = WaveformData();

        expect(waveform.isEmpty, isTrue);
        expect(waveform.sampleCount, 0);
        expect(waveform.samples, isEmpty);
      });

      test('starts with zero amplitudes', () {
        final waveform = WaveformData();

        expect(waveform.averageAmplitude, 0.0);
        expect(waveform.peakAmplitude, 0.0);
        expect(waveform.currentAmplitude, 0.0);
      });
    });

    group('addSample', () {
      test('adds sample and updates count', () {
        final waveform = WaveformData();
        final updated = waveform.addSample(0.5);

        expect(updated.sampleCount, 1);
        expect(updated.samples, [0.5]);
      });

      test('returns new instance (immutable)', () {
        final original = WaveformData();
        final updated = original.addSample(0.5);

        expect(identical(original, updated), isFalse);
        expect(original.sampleCount, 0);
        expect(updated.sampleCount, 1);
      });

      test('clamps values above 1.0', () {
        final waveform = WaveformData();
        final updated = waveform.addSample(1.5);

        expect(updated.samples, [1.0]);
      });

      test('clamps values below 0.0', () {
        final waveform = WaveformData();
        final updated = waveform.addSample(-0.5);

        expect(updated.samples, [0.0]);
      });

      test('maintains order oldest to newest', () {
        var waveform = WaveformData();
        waveform = waveform.addSample(0.1);
        waveform = waveform.addSample(0.2);
        waveform = waveform.addSample(0.3);

        expect(waveform.samples, [0.1, 0.2, 0.3]);
      });

      test('rolls buffer when maxSamples exceeded', () {
        var waveform = WaveformData(maxSamples: 3);
        waveform = waveform.addSample(0.1);
        waveform = waveform.addSample(0.2);
        waveform = waveform.addSample(0.3);
        waveform = waveform.addSample(0.4);

        expect(waveform.sampleCount, 3);
        expect(waveform.samples, [0.2, 0.3, 0.4]);
      });

      test('calculates averageAmplitude correctly', () {
        var waveform = WaveformData();
        waveform = waveform.addSample(0.2);
        waveform = waveform.addSample(0.4);
        waveform = waveform.addSample(0.6);

        expect(waveform.averageAmplitude, closeTo(0.4, 0.001));
      });

      test('tracks peakAmplitude correctly', () {
        var waveform = WaveformData();
        waveform = waveform.addSample(0.3);
        waveform = waveform.addSample(0.8);
        waveform = waveform.addSample(0.5);

        expect(waveform.peakAmplitude, 0.8);
      });

      test('updates currentAmplitude to most recent', () {
        var waveform = WaveformData();
        waveform = waveform.addSample(0.3);

        expect(waveform.currentAmplitude, 0.3);

        waveform = waveform.addSample(0.7);

        expect(waveform.currentAmplitude, 0.7);
      });
    });

    group('clear', () {
      test('returns empty waveform', () {
        var waveform = WaveformData();
        waveform = waveform.addSample(0.5);
        waveform = waveform.addSample(0.7);

        final cleared = waveform.clear();

        expect(cleared.isEmpty, isTrue);
        expect(cleared.sampleCount, 0);
      });

      test('preserves maxSamples', () {
        var waveform = WaveformData(maxSamples: 100);
        waveform = waveform.addSample(0.5);

        final cleared = waveform.clear();

        expect(cleared.maxSamples, 100);
      });
    });

    group('isEmpty and isFull', () {
      test('isEmpty is true when empty', () {
        final waveform = WaveformData();

        expect(waveform.isEmpty, isTrue);
        expect(waveform.isFull, isFalse);
      });

      test('isEmpty is false after adding sample', () {
        final waveform = WaveformData().addSample(0.5);

        expect(waveform.isEmpty, isFalse);
      });

      test('isFull is true at maxSamples', () {
        var waveform = WaveformData(maxSamples: 3);
        waveform = waveform.addSample(0.1);
        waveform = waveform.addSample(0.2);
        waveform = waveform.addSample(0.3);

        expect(waveform.isFull, isTrue);
      });

      test('isFull remains true when buffer rolls', () {
        var waveform = WaveformData(maxSamples: 3);
        waveform = waveform.addSample(0.1);
        waveform = waveform.addSample(0.2);
        waveform = waveform.addSample(0.3);
        waveform = waveform.addSample(0.4);

        expect(waveform.isFull, isTrue);
        expect(waveform.sampleCount, 3);
      });
    });

    group('getSamplesForRendering', () {
      test('returns zeros when empty', () {
        final waveform = WaveformData();
        final samples = waveform.getSamplesForRendering(5);

        expect(samples, [0.0, 0.0, 0.0, 0.0, 0.0]);
      });

      test('returns exact samples when count matches', () {
        var waveform = WaveformData();
        waveform = waveform.addSample(0.1);
        waveform = waveform.addSample(0.2);
        waveform = waveform.addSample(0.3);

        final samples = waveform.getSamplesForRendering(3);

        expect(samples, [0.1, 0.2, 0.3]);
      });

      test('pads with zeros at beginning when fewer samples', () {
        var waveform = WaveformData();
        waveform = waveform.addSample(0.5);
        waveform = waveform.addSample(0.7);

        final samples = waveform.getSamplesForRendering(5);

        expect(samples.length, 5);
        expect(samples[0], 0.0);
        expect(samples[1], 0.0);
        expect(samples[2], 0.0);
        expect(samples[3], 0.5);
        expect(samples[4], 0.7);
      });

      test('downsamples when more samples than requested', () {
        var waveform = WaveformData(maxSamples: 10);
        for (var i = 0; i < 10; i++) {
          waveform = waveform.addSample(i / 10);
        }

        final samples = waveform.getSamplesForRendering(5);

        expect(samples.length, 5);
        // Should take evenly distributed samples
      });

      test('returns correct length for any count', () {
        var waveform = WaveformData();
        waveform = waveform.addSample(0.5);

        expect(waveform.getSamplesForRendering(1).length, 1);
        expect(waveform.getSamplesForRendering(10).length, 10);
        expect(waveform.getSamplesForRendering(100).length, 100);
      });
    });
  });

  group('WaveformConfig', () {
    group('constructor', () {
      test('has correct default values', () {
        const config = WaveformConfig();

        expect(config.barCount, 30);
        expect(config.minBarHeight, 0.05);
        expect(config.barWidth, 3.0);
        expect(config.barSpacing, 2.0);
        expect(config.barRadius, 1.5);
      });

      test('allows custom values', () {
        const config = WaveformConfig(
          barCount: 50,
          minBarHeight: 0.1,
          barWidth: 4.0,
          barSpacing: 1.0,
          barRadius: 2.0,
        );

        expect(config.barCount, 50);
        expect(config.minBarHeight, 0.1);
        expect(config.barWidth, 4.0);
        expect(config.barSpacing, 1.0);
        expect(config.barRadius, 2.0);
      });

      test('is const constructible', () {
        const config1 = WaveformConfig(barCount: 20);
        const config2 = WaveformConfig(barCount: 20);

        expect(identical(config1, config2), isTrue);
      });
    });

    group('totalWidth', () {
      test('calculates correctly with default values', () {
        const config = WaveformConfig();

        // (3.0 + 2.0) * 30 - 2.0 = 148.0
        expect(config.totalWidth, 148.0);
      });

      test('calculates correctly with custom values', () {
        const config = WaveformConfig(
          barCount: 10,
          barWidth: 5.0,
          barSpacing: 3.0,
        );

        // (5.0 + 3.0) * 10 - 3.0 = 77.0
        expect(config.totalWidth, 77.0);
      });

      test('handles single bar', () {
        const config = WaveformConfig(
          barCount: 1,
          barWidth: 10.0,
          barSpacing: 5.0,
        );

        // (10.0 + 5.0) * 1 - 5.0 = 10.0
        expect(config.totalWidth, 10.0);
      });

      test('handles zero spacing', () {
        const config = WaveformConfig(
          barCount: 5,
          barWidth: 4.0,
          barSpacing: 0.0,
        );

        // (4.0 + 0.0) * 5 - 0.0 = 20.0
        expect(config.totalWidth, 20.0);
      });
    });
  });
}
