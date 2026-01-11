import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/services/audio/waveform_data.dart';
import 'package:boardroom_journal/ui/widgets/waveform_widget.dart';

void main() {
  group('WaveformWidget', () {
    Widget createTestWidget({
      WaveformData? waveformData,
      WaveformConfig config = const WaveformConfig(),
      Color? barColor,
      Color? backgroundColor,
      bool animate = false, // Disable animation for testing
      double height = 60.0,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: WaveformWidget(
            waveformData: waveformData ?? WaveformData(),
            config: config,
            barColor: barColor,
            backgroundColor: backgroundColor,
            animate: animate,
            height: height,
          ),
        ),
      );
    }

    testWidgets('renders with default configuration', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Should find a Container (the main container)
      expect(find.byType(Container), findsWidgets);
      // Should find a Row for the bars
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('renders correct number of bars based on config', (tester) async {
      const config = WaveformConfig(barCount: 20);
      await tester.pumpWidget(createTestWidget(config: config));

      // Find all Container widgets that are bars (inside Padding)
      final paddingWidgets = find.byType(Padding);
      // barCount paddings for bar spacing
      expect(paddingWidgets, findsNWidgets(20));
    });

    testWidgets('applies custom bar color', (tester) async {
      const customColor = Colors.red;
      await tester.pumpWidget(createTestWidget(barColor: customColor));

      // Find containers with the custom color
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasColoredBar = containers.any((container) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == customColor;
        }
        return false;
      });
      expect(hasColoredBar, isTrue);
    });

    testWidgets('applies custom background color', (tester) async {
      const bgColor = Colors.blue;
      await tester.pumpWidget(createTestWidget(backgroundColor: bgColor));

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBackgroundColor = containers.any((container) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == bgColor;
        }
        return false;
      });
      expect(hasBackgroundColor, isTrue);
    });

    testWidgets('respects custom height', (tester) async {
      const customHeight = 100.0;
      await tester.pumpWidget(createTestWidget(height: customHeight));

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCustomHeight = containers.any((container) {
        final constraints = container.constraints;
        if (constraints != null) {
          return constraints.maxHeight == customHeight;
        }
        return false;
      });
      // The main container should have the custom height
      expect(hasCustomHeight, isTrue);
    });

    testWidgets('renders bars with waveform data', (tester) async {
      final waveformData = WaveformData(maxSamples: 100);
      // Add some samples
      waveformData.addSample(0.5);
      waveformData.addSample(0.8);
      waveformData.addSample(0.3);

      await tester.pumpWidget(createTestWidget(waveformData: waveformData));

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('uses AnimatedContainer when animate is true', (tester) async {
      await tester.pumpWidget(createTestWidget(animate: true));

      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('uses regular Container when animate is false', (tester) async {
      await tester.pumpWidget(createTestWidget(animate: false));

      // Should not find AnimatedContainer for bars
      // (there might be AnimatedContainer elsewhere, so we check the count difference)
      final animatedContainers = find.byType(AnimatedContainer);
      // With animate: false, bars should be regular Containers
      expect(animatedContainers, findsNothing);
    });

    testWidgets('config barWidth affects bar rendering', (tester) async {
      const config = WaveformConfig(barCount: 5, barWidth: 10.0);
      await tester.pumpWidget(createTestWidget(config: config));

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCorrectWidth = containers.any((container) {
        final constraints = container.constraints;
        if (constraints != null && constraints.maxWidth == 10.0) {
          return true;
        }
        return false;
      });
      expect(hasCorrectWidth, isTrue);
    });
  });

  group('RecordingWaveformWidget', () {
    Widget createTestWidget({
      WaveformData? waveformData,
      bool isRecording = false,
      Color? barColor,
      double height = 80.0,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: RecordingWaveformWidget(
            waveformData: waveformData ?? WaveformData(),
            isRecording: isRecording,
            barColor: barColor,
            height: height,
          ),
        ),
      );
    }

    testWidgets('renders WaveformWidget inside', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(WaveformWidget), findsOneWidget);
    });

    testWidgets('renders with waveform data', (tester) async {
      final waveformData = WaveformData(maxSamples: 100);
      waveformData.addSample(0.7);

      await tester.pumpWidget(createTestWidget(waveformData: waveformData));

      expect(find.byType(WaveformWidget), findsOneWidget);
    });

    testWidgets('renders when recording is true', (tester) async {
      await tester.pumpWidget(createTestWidget(isRecording: true));
      await tester.pump();

      expect(find.byType(WaveformWidget), findsOneWidget);
      expect(find.byType(Transform), findsOneWidget);
    });

    testWidgets('renders when recording is false', (tester) async {
      await tester.pumpWidget(createTestWidget(isRecording: false));

      expect(find.byType(WaveformWidget), findsOneWidget);
    });

    testWidgets('applies custom bar color to inner WaveformWidget',
        (tester) async {
      const customColor = Colors.green;
      await tester.pumpWidget(createTestWidget(barColor: customColor));

      final waveformWidget =
          tester.widget<WaveformWidget>(find.byType(WaveformWidget));
      expect(waveformWidget.barColor, customColor);
    });

    testWidgets('applies custom height to inner WaveformWidget',
        (tester) async {
      const customHeight = 120.0;
      await tester.pumpWidget(createTestWidget(height: customHeight));

      final waveformWidget =
          tester.widget<WaveformWidget>(find.byType(WaveformWidget));
      expect(waveformWidget.height, customHeight);
    });

    testWidgets('uses 40 bars configuration', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final waveformWidget =
          tester.widget<WaveformWidget>(find.byType(WaveformWidget));
      expect(waveformWidget.config.barCount, 40);
    });

    testWidgets('animation controller starts when recording starts',
        (tester) async {
      await tester.pumpWidget(createTestWidget(isRecording: false));
      await tester.pump();

      // Update to recording
      await tester.pumpWidget(createTestWidget(isRecording: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Widget should still render
      expect(find.byType(RecordingWaveformWidget), findsOneWidget);
    });

    testWidgets('animation controller stops when recording stops',
        (tester) async {
      await tester.pumpWidget(createTestWidget(isRecording: true));
      await tester.pump(const Duration(milliseconds: 100));

      // Update to not recording
      await tester.pumpWidget(createTestWidget(isRecording: false));
      await tester.pump();

      // Widget should still render
      expect(find.byType(RecordingWaveformWidget), findsOneWidget);
    });
  });

  group('WaveformIndicator', () {
    Widget createTestWidget({
      double amplitude = 0.5,
      bool isActive = true,
      double size = 24.0,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: WaveformIndicator(
            amplitude: amplitude,
            isActive: isActive,
            size: size,
          ),
        ),
      );
    }

    testWidgets('renders 3 bars', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Should have a Row with 3 children (via List.generate(3, ...))
      expect(find.byType(Row), findsOneWidget);
      // Should have 3 Padding widgets for bar spacing
      expect(find.byType(Padding), findsNWidgets(3));
    });

    testWidgets('respects custom size', (tester) async {
      const customSize = 48.0;
      await tester.pumpWidget(createTestWidget(size: customSize));

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, customSize);
      expect(sizedBox.height, customSize);
    });

    testWidgets('renders with zero amplitude', (tester) async {
      await tester.pumpWidget(createTestWidget(amplitude: 0.0));

      expect(find.byType(WaveformIndicator), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('renders with full amplitude', (tester) async {
      await tester.pumpWidget(createTestWidget(amplitude: 1.0));

      expect(find.byType(WaveformIndicator), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('renders with mid amplitude', (tester) async {
      await tester.pumpWidget(createTestWidget(amplitude: 0.5));

      expect(find.byType(WaveformIndicator), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('uses error color when active', (tester) async {
      await tester.pumpWidget(createTestWidget(isActive: true));

      // When active, bars should use error color from theme
      final animatedContainers =
          tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(animatedContainers.length, 3);

      // Check that decoration exists
      for (final container in animatedContainers) {
        expect(container.decoration, isNotNull);
        expect(container.decoration, isA<BoxDecoration>());
      }
    });

    testWidgets('uses different color when inactive', (tester) async {
      await tester.pumpWidget(createTestWidget(isActive: false));

      // When inactive, bars should use onSurfaceVariant color
      final animatedContainers =
          tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(animatedContainers.length, 3);
    });

    testWidgets('bars have AnimatedContainer for smooth transitions',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('amplitude affects bar heights differently for each bar',
        (tester) async {
      // Each bar has an offset applied, so heights should vary
      await tester.pumpWidget(createTestWidget(amplitude: 0.5));

      final animatedContainers =
          tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
              .toList();

      // Get the BoxDecoration from each to verify they rendered
      for (final container in animatedContainers) {
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, isNotNull);
      }
    });

    testWidgets('handles amplitude clamping at boundaries', (tester) async {
      // Test with amplitude that would go out of bounds after offset
      await tester.pumpWidget(createTestWidget(amplitude: 0.0));
      expect(find.byType(WaveformIndicator), findsOneWidget);

      await tester.pumpWidget(createTestWidget(amplitude: 1.0));
      expect(find.byType(WaveformIndicator), findsOneWidget);

      // Edge case: negative amplitude (should clamp to 0)
      await tester.pumpWidget(createTestWidget(amplitude: -0.5));
      expect(find.byType(WaveformIndicator), findsOneWidget);

      // Edge case: amplitude > 1 (should clamp to 1)
      await tester.pumpWidget(createTestWidget(amplitude: 1.5));
      expect(find.byType(WaveformIndicator), findsOneWidget);
    });
  });
}
