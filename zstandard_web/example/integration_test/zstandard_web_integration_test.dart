import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiri_check/kiri_check.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:leak_tracker_testing/leak_tracker_testing.dart';
import 'package:zstandard_platform_web_example/main.dart';
import 'package:zstandard_web/zstandard_web.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ZstandardWeb with zstd.js and zstd.wasm', () {
    late ZstandardWeb zstandardWeb;

    setUp(() {
      zstandardWeb = ZstandardWeb();
    });

    testWidgets('Verify Platform version', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Text && widget.data!.startsWith('Running on:'),
        ),
        findsOneWidget,
      );
    });

    test('getPlatformVersion returns a non-null userAgent string', () async {
      final version = await zstandardWeb.getPlatformVersion();
      expect(version, isNotNull);
    });

    test('compress and decompress roundtrip for data shorter than 9 bytes',
        () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await zstandardWeb.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed =
          await zstandardWeb.decompress(compressed ?? Uint8List(0));
      expect(decompressed, equals(data));
    });

    test('compress and decompress small data', () async {
      final data = Uint8List.fromList(List.generate(10, (int i) => i));
      final compressed = await zstandardWeb.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed =
          await zstandardWeb.decompress(compressed ?? Uint8List(0));
      expect(decompressed, equals(data));
    });

    test('compress and decompress large data', () async {
      final data =
          Uint8List.fromList(List<int>.generate(100000, (int i) => i % 256));
      final compressed = await zstandardWeb.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed =
          await zstandardWeb.decompress(compressed ?? Uint8List(0));
      expect(decompressed, equals(data));
    });

    test('compress and decompress empty data', () async {
      final data = Uint8List(0);
      final compressed = await zstandardWeb.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed =
          await zstandardWeb.decompress(compressed ?? Uint8List(0));
      expect(decompressed, equals(data));
    });

    test('compress with levels 1, 3, 10, 22', () async {
      final data = Uint8List.fromList(List.filled(1000, 42));
      for (final level in [1, 3, 10, 22]) {
        final compressed = await zstandardWeb.compress(data, level);
        expect(compressed, isNotNull);
        final decompressed =
            await zstandardWeb.decompress(compressed ?? Uint8List(0));
        expect(decompressed, equals(data));
      }
    });

    test('decompress corrupted data throws', () async {
      final corrupted =
          Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(
        () async => await zstandardWeb.decompress(corrupted),
        throwsException,
      );
    });

    test('decompress random bytes throws', () async {
      final random =
          Uint8List.fromList(List.generate(64, (int i) => (i * 31) % 256));
      expect(
        () async => await zstandardWeb.decompress(random),
        throwsException,
      );
    });

    test('compress and decompress do not leak', () async {
      final data = Uint8List.fromList(List.generate(10, (int i) => i));
      final compressed = await zstandardWeb.compress(data, 3);
      expect(compressed, isNotNull);
      final decompressed =
          await zstandardWeb.decompress(compressed ?? Uint8List(0));
      expect(decompressed, equals(data));
      if (LeakTracking.isStarted) {
        final leaks = await LeakTracking.collectLeaks();
        expect(leaks, isLeakFree);
      }
    });

  });

  group('Property-based tests', () {
    property(
      'roundtrip: decompress(compress(x)) == x',
      () {
        forAll(
          binary(minLength: 0, maxLength: 1000),
          (List<int> data) async {
            final input = Uint8List.fromList(data);
            final z = ZstandardWeb();
            final compressed = await z.compress(input, 3);
            if (compressed == null) return;
            final decompressed = await z.decompress(compressed);
            expect(decompressed, isNotNull);
            expect(List<int>.from(decompressed!), data);
          },
          maxExamples: 100,
        );
      },
    );
  });
}
