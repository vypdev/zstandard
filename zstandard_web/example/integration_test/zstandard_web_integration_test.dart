import 'dart:async';
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

    test(
      'compress and decompress roundtrip for data shorter than 9 bytes',
      () async {
        final data = Uint8List.fromList([1, 2, 3, 4, 5]);
        expect(data, isNotEmpty);
        final compressed = await zstandardWeb.compress(data, 3);
        expect(compressed, isNotNull);
        expect(compressed!.isNotEmpty, isTrue);
        expect(compressed, isNot(equals(data)));
        final decompressed = await zstandardWeb.decompress(compressed);
        expect(decompressed, equals(data));
      },
    );

    test('compress and decompress small data', () async {
      final data = Uint8List.fromList(List.generate(10, (int i) => i));
      expect(data, isNotEmpty);
      final compressed = await zstandardWeb.compress(data, 3);
      expect(compressed, isNotNull);
      expect(compressed!.isNotEmpty, isTrue);
      final decompressed = await zstandardWeb.decompress(compressed);
      expect(decompressed, equals(data));
    });

    test('compress and decompress large data', () async {
      final data = Uint8List.fromList(
        List<int>.generate(100000, (int i) => i % 256),
      );
      expect(data, isNotEmpty);
      final compressed = await zstandardWeb.compress(data, 3);
      expect(compressed, isNotNull);
      expect(compressed!.isNotEmpty, isTrue);
      final decompressed = await zstandardWeb.decompress(compressed);
      expect(decompressed, equals(data));
    });

    test('compress and decompress empty data', () async {
      final data = Uint8List(0);
      final compressed = await zstandardWeb.compress(data, 3);
      expect(compressed, isNotNull);
      expect(compressed!.isNotEmpty, isTrue);
      final decompressed = await zstandardWeb.decompress(compressed);
      expect(decompressed, equals(data));
    });

    test('compress with levels 1, 3, 10, 22', () async {
      final data = Uint8List.fromList(List.filled(1000, 42));
      expect(data, isNotEmpty);
      for (final level in [1, 3, 10, 22]) {
        final compressed = await zstandardWeb.compress(data, level);
        expect(compressed, isNotNull);
        expect(compressed!.isNotEmpty, isTrue);
        final decompressed = await zstandardWeb.decompress(compressed);
        expect(decompressed, equals(data));
      }
    });

    test('decompress corrupted data returns null', () async {
      final corrupted = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(await zstandardWeb.decompress(corrupted), isNull);
    });

    test('decompress random bytes returns null', () async {
      final random = Uint8List.fromList(
        List.generate(64, (int i) => (i * 31) % 256),
      );
      expect(await zstandardWeb.decompress(random), isNull);
    });

    test('decompresses a frame without a declared content size', () async {
      const frameWithoutContentSize = <int>[
        0x28,
        0xb5,
        0x2f,
        0xfd,
        0x04,
        0x58,
        0x91,
        0x00,
        0x00,
        0x75,
        0x6e,
        0x6b,
        0x6e,
        0x6f,
        0x77,
        0x6e,
        0x2d,
        0x73,
        0x69,
        0x7a,
        0x65,
        0x20,
        0x66,
        0x72,
        0x61,
        0x6d,
        0x65,
        0xab,
        0x02,
        0x28,
        0xf0,
      ];
      expect(
        await zstandardWeb.decompress(
          Uint8List.fromList(frameWithoutContentSize),
        ),
        equals('unknown-size frame'.codeUnits),
      );
    });

    test('decompresses concatenated frames', () async {
      final first = Uint8List.fromList('first frame'.codeUnits);
      final second = Uint8List.fromList('second frame'.codeUnits);
      final compressedFirst = await zstandardWeb.compress(first, 3);
      final compressedSecond = await zstandardWeb.compress(second, 3);
      expect(compressedFirst, isNotNull);
      expect(compressedSecond, isNotNull);

      final concatenated = Uint8List.fromList([
        ...compressedFirst!,
        ...compressedSecond!,
      ]);
      expect(
        await zstandardWeb.decompress(concatenated),
        equals([...first, ...second]),
      );
    });

    test('enforces the decompressed output limit', () async {
      final compressed = await zstandardWeb.compress(Uint8List(1024), 3);
      expect(compressed, isNotNull);
      expect(
        await zstandardWeb.decompressWithOptions(
          compressed!,
          maxOutputSize: 1023,
        ),
        isNull,
      );
      expect(
        await zstandardWeb.decompressWithOptions(
          compressed,
          maxOutputSize: 1024,
        ),
        equals(Uint8List(1024)),
      );
    });

    test('compression yields the browser event loop to a worker', () async {
      var timerRan = false;
      Timer.run(() => timerRan = true);

      final compressed = zstandardWeb.compress(Uint8List(1024 * 1024), 3);
      await Future<void>.delayed(Duration.zero);

      expect(timerRan, isTrue);
      expect(await compressed, isNotNull);
    });

    test('compress and decompress do not leak', () async {
      final data = Uint8List.fromList(List.generate(10, (int i) => i));
      expect(data, isNotEmpty);
      final compressed = await zstandardWeb.compress(data, 3);
      expect(compressed, isNotNull);
      expect(compressed!.isNotEmpty, isTrue);
      final decompressed = await zstandardWeb.decompress(compressed);
      expect(decompressed, equals(data));
      if (LeakTracking.isStarted) {
        final leaks = await LeakTracking.collectLeaks();
        expect(leaks, isLeakFree);
      }
    });
  });

  group('Property-based tests', () {
    property('roundtrip: decompress(compress(x)) == x', () {
      forAll(binary(minLength: 1, maxLength: 1000), (List<int> data) async {
        final input = Uint8List.fromList(data);
        expect(input, isNotEmpty);
        final z = ZstandardWeb();
        final compressed = await z.compress(input, 3);
        expect(compressed, isNotNull);
        expect(compressed!.isNotEmpty, isTrue);
        final decompressed = await z.decompress(compressed);
        expect(decompressed, isNotNull);
        expect(List<int>.from(decompressed!), data);
      }, maxExamples: 100);
    });
  });
}
