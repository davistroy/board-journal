import 'dart:collection';

/// Data container for audio waveform visualization.
///
/// Maintains a rolling buffer of amplitude samples that can be
/// used to render a waveform visualization during recording.
class WaveformData {
  /// Maximum number of samples to keep in the buffer.
  final int maxSamples;

  /// Internal buffer of normalized amplitude samples (0.0 to 1.0).
  final Queue<double> _samples;

  /// Current average amplitude (useful for overall level indication).
  double _averageAmplitude = 0.0;

  /// Peak amplitude in the current buffer.
  double _peakAmplitude = 0.0;

  WaveformData({
    this.maxSamples = 50,
  }) : _samples = Queue<double>();

  /// Creates a copy with updated samples.
  WaveformData._copy({
    required this.maxSamples,
    required Queue<double> samples,
    required double averageAmplitude,
    required double peakAmplitude,
  })  : _samples = Queue<double>.from(samples),
        _averageAmplitude = averageAmplitude,
        _peakAmplitude = peakAmplitude;

  /// Adds a new normalized amplitude sample (0.0 to 1.0).
  WaveformData addSample(double normalizedAmplitude) {
    final newSamples = Queue<double>.from(_samples);
    newSamples.add(normalizedAmplitude.clamp(0.0, 1.0));

    // Remove oldest samples if we exceed max
    while (newSamples.length > maxSamples) {
      newSamples.removeFirst();
    }

    // Calculate new average and peak
    double sum = 0.0;
    double peak = 0.0;
    for (final sample in newSamples) {
      sum += sample;
      if (sample > peak) peak = sample;
    }
    final avg = newSamples.isNotEmpty ? sum / newSamples.length : 0.0;

    return WaveformData._copy(
      maxSamples: maxSamples,
      samples: newSamples,
      averageAmplitude: avg,
      peakAmplitude: peak,
    );
  }

  /// Clears all samples and returns a new empty waveform.
  WaveformData clear() {
    return WaveformData(maxSamples: maxSamples);
  }

  /// List of amplitude samples (0.0 to 1.0), oldest first.
  List<double> get samples => _samples.toList();

  /// Number of samples currently in the buffer.
  int get sampleCount => _samples.length;

  /// Whether the buffer is empty.
  bool get isEmpty => _samples.isEmpty;

  /// Whether the buffer is full.
  bool get isFull => _samples.length >= maxSamples;

  /// Average amplitude of samples in buffer (0.0 to 1.0).
  double get averageAmplitude => _averageAmplitude;

  /// Peak amplitude in buffer (0.0 to 1.0).
  double get peakAmplitude => _peakAmplitude;

  /// Most recent amplitude sample.
  double get currentAmplitude =>
      _samples.isNotEmpty ? _samples.last : 0.0;

  /// Returns samples normalized to a specific count for consistent rendering.
  ///
  /// If we have fewer samples than [count], pads with zeros.
  /// If we have more, takes evenly distributed samples.
  List<double> getSamplesForRendering(int count) {
    if (_samples.isEmpty) {
      return List.filled(count, 0.0);
    }

    final sampleList = _samples.toList();

    if (sampleList.length == count) {
      return sampleList;
    }

    if (sampleList.length < count) {
      // Pad with zeros at the beginning
      final padding = count - sampleList.length;
      return [
        ...List.filled(padding, 0.0),
        ...sampleList,
      ];
    }

    // Downsample by taking evenly distributed samples
    final result = <double>[];
    final step = sampleList.length / count;
    for (var i = 0; i < count; i++) {
      final index = (i * step).floor().clamp(0, sampleList.length - 1);
      result.add(sampleList[index]);
    }
    return result;
  }
}

/// Configuration for waveform rendering.
class WaveformConfig {
  /// Number of bars to display in the waveform.
  final int barCount;

  /// Minimum height of bars as fraction (0.0 to 1.0).
  final double minBarHeight;

  /// Width of each bar in pixels.
  final double barWidth;

  /// Spacing between bars in pixels.
  final double barSpacing;

  /// Corner radius for bars.
  final double barRadius;

  const WaveformConfig({
    this.barCount = 30,
    this.minBarHeight = 0.05,
    this.barWidth = 3.0,
    this.barSpacing = 2.0,
    this.barRadius = 1.5,
  });

  /// Total width of the waveform visualization.
  double get totalWidth => (barWidth + barSpacing) * barCount - barSpacing;
}
