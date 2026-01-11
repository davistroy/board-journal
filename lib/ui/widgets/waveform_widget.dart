import 'package:flutter/material.dart';

import '../../services/audio/waveform_data.dart';

/// Widget that displays an audio waveform visualization.
///
/// Renders a series of vertical bars that represent amplitude levels
/// from audio recording. Used during voice recording to show activity.
class WaveformWidget extends StatelessWidget {
  /// The waveform data to display.
  final WaveformData waveformData;

  /// Configuration for rendering.
  final WaveformConfig config;

  /// Color for the waveform bars.
  final Color? barColor;

  /// Background color.
  final Color? backgroundColor;

  /// Whether to animate bar changes.
  final bool animate;

  /// Height of the waveform visualization.
  final double height;

  const WaveformWidget({
    super.key,
    required this.waveformData,
    this.config = const WaveformConfig(),
    this.barColor,
    this.backgroundColor,
    this.animate = true,
    this.height = 60.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBarColor = barColor ?? theme.colorScheme.primary;
    final effectiveBgColor =
        backgroundColor ?? theme.colorScheme.surfaceContainerHighest;

    final samples = waveformData.getSamplesForRendering(config.barCount);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(config.barCount, (index) {
          final amplitude = samples[index];
          final barHeight = _calculateBarHeight(amplitude);

          return Padding(
            padding: EdgeInsets.only(
              right: index < config.barCount - 1 ? config.barSpacing : 0,
            ),
            child: animate
                ? AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: config.barWidth,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: effectiveBarColor,
                      borderRadius: BorderRadius.circular(config.barRadius),
                    ),
                  )
                : Container(
                    width: config.barWidth,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: effectiveBarColor,
                      borderRadius: BorderRadius.circular(config.barRadius),
                    ),
                  ),
          );
        }),
      ),
    );
  }

  double _calculateBarHeight(double amplitude) {
    final maxHeight = height - 8; // Account for padding
    final minHeight = maxHeight * config.minBarHeight;
    return minHeight + (amplitude * (maxHeight - minHeight));
  }
}

/// A centered waveform widget for recording screens.
///
/// Includes a subtle pulsing animation when recording is active.
class RecordingWaveformWidget extends StatefulWidget {
  /// The waveform data to display.
  final WaveformData waveformData;

  /// Whether recording is currently active.
  final bool isRecording;

  /// Color for the waveform bars.
  final Color? barColor;

  /// Height of the waveform visualization.
  final double height;

  const RecordingWaveformWidget({
    super.key,
    required this.waveformData,
    required this.isRecording,
    this.barColor,
    this.height = 80.0,
  });

  @override
  State<RecordingWaveformWidget> createState() =>
      _RecordingWaveformWidgetState();
}

class _RecordingWaveformWidgetState extends State<RecordingWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RecordingWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isRecording ? _pulseAnimation.value : 1.0,
          child: WaveformWidget(
            waveformData: widget.waveformData,
            barColor: widget.barColor,
            height: widget.height,
            config: const WaveformConfig(
              barCount: 40,
              barWidth: 4.0,
              barSpacing: 3.0,
            ),
          ),
        );
      },
    );
  }
}

/// Compact waveform indicator for showing recording activity.
class WaveformIndicator extends StatelessWidget {
  /// Current amplitude (0.0 to 1.0).
  final double amplitude;

  /// Whether recording is active.
  final bool isActive;

  /// Size of the indicator.
  final double size;

  const WaveformIndicator({
    super.key,
    required this.amplitude,
    this.isActive = true,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return SizedBox(
      width: size,
      height: size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(3, (index) {
          // Create offset animation effect
          final offset = (index - 1) * 0.2;
          final adjustedAmplitude =
              ((amplitude + offset).clamp(0.0, 1.0) * 0.7) + 0.3;

          return Padding(
            padding: EdgeInsets.only(right: index < 2 ? 2 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 3,
              height: size * adjustedAmplitude,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          );
        }),
      ),
    );
  }
}
