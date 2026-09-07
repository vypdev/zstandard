import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:leak_tracker/leak_tracker.dart';
import 'package:leak_tracker_testing/leak_tracker_testing.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zstandard_cli/src/cli_runner.dart';
import 'package:zstandard_cli/zstandard_cli.dart';
import 'package:zstandard_cli/src/utils/constants.dart';
import 'package:zstandard_cli/src/utils/lib_loader.dart';

void main() {
  final bool skipPlatform =
      !Platform.isMacOS && !Platform.isWindows && !Platform.isLinux;

  setUpAll(() {
    if (!LeakTracking.isStarted) {
      LeakTracking.start();
    }
  });

  group('Native library resolver', () {
    test('selects every supported platform and ABI deterministically', () {
      expect(
        zstdLibraryFileName(
          operatingSystem: 'windows',
          abi: Abi.windowsArm64,
        ),
        'zstandard_windows_arm64.dll',
      );
      expect(
        zstdLibraryFileName(
          operatingSystem: 'windows',
          abi: Abi.windowsX64,
        ),
        'zstandard_windows_x64.dll',
      );
      expect(
        zstdLibraryFileName(
          operatingSystem: 'linux',
          abi: Abi.linuxArm64,
        ),
        'libzstandard_linux_arm64.so',
      );
      expect(
        zstdLibraryFileName(
          operatingSystem: 'linux',
          abi: Abi.linuxX64,
        ),
        'libzstandard_linux_x64.so',
      );
      expect(
        zstdLibraryFileName(operatingSystem: 'macos', abi: Abi.macosArm64),
        'libzstandard_macos.dylib',
      );
      expect(
        () => zstdLibraryFileName(
          operatingSystem: 'windows',
          abi: Abi.linuxX64,
        ),
        throwsUnsupportedError,
      );
      expect(
        () => zstdLibraryFileName(
          operatingSystem: 'linux',
          abi: Abi.windowsX64,
        ),
        throwsUnsupportedError,
      );
      expect(
        () => zstdLibraryFileName(
          operatingSystem: 'android',
          abi: Abi.androidArm64,
        ),
        throwsUnsupportedError,
      );
    });

    test('honors an explicit existing library and rejects a missing one',
        () async {
      final directory = await Directory.systemTemp.createTemp('zstd_override');
      try {
        final library = await File(
          path.join(directory.path, zstdLibraryFileName()),
        ).create();
        expect(
          await resolveZstdLibraryPath(
            environment: {'ZSTANDARD_CLI_LIBRARY': library.path},
          ),
          path.normalize(library.path),
        );
        expect(
          resolveZstdLibraryPath(
            environment: {
              'ZSTANDARD_CLI_LIBRARY': path.join(directory.path, 'missing'),
            },
          ),
          throwsA(isA<ArgumentError>()),
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('resolves package-config, executable, and legacy fallbacks', () async {
      final directory = await Directory.systemTemp.createTemp('zstd_fallback');
      try {
        final packageRoot = await Directory(
          path.join(directory.path, 'package'),
        ).create();
        final packageLibrary = await File(
          path.join(
            packageRoot.path,
            'lib',
            'src',
            'bin',
            zstdLibraryFileName(),
          ),
        ).create(recursive: true);
        final packageConfig = await File(
          path.join(directory.path, '.dart_tool', 'package_config.json'),
        ).create(recursive: true);
        final rootWithoutTrailingSlash =
            packageRoot.uri.toString().replaceFirst(RegExp(r'/$'), '');
        await packageConfig.writeAsString(
          jsonEncode({
            'configVersion': 2,
            'packages': [
              {
                'name': 'zstandard_cli',
                'rootUri': rootWithoutTrailingSlash,
                'packageUri': 'lib/',
              },
            ],
          }),
        );

        expect(
          await resolveZstdLibraryFromPackageConfig(packageConfig.uri),
          path.normalize(packageLibrary.path),
        );
        expect(
          await resolveZstdLibraryPath(
            environment: const {},
            packageConfigs: [packageConfig.uri],
            executableDirectory: path.join(directory.path, 'empty-executable'),
            legacyPackageRoot: path.join(directory.path, 'empty-legacy'),
          ),
          path.normalize(packageLibrary.path),
        );

        final executableDirectory = await Directory(
          path.join(directory.path, 'executable'),
        ).create();
        final executableLibrary = await File(
          path.join(executableDirectory.path, zstdLibraryFileName()),
        ).create();
        expect(
          await resolveZstdLibraryPath(
            environment: const {},
            packageConfigs: const [],
            executableDirectory: executableDirectory.path,
            legacyPackageRoot: path.join(directory.path, 'empty-legacy'),
          ),
          path.normalize(executableLibrary.path),
        );

        final legacyRoot = await Directory(
          path.join(directory.path, 'legacy'),
        ).create();
        final legacyLibrary = await File(
          getZstdLibraryPath(packageRoot: legacyRoot.path),
        ).create(recursive: true);
        expect(
          await resolveZstdLibraryPath(
            environment: const {},
            packageConfigs: const [],
            executableDirectory: path.join(directory.path, 'empty-executable'),
            legacyPackageRoot: legacyRoot.path,
          ),
          path.normalize(legacyLibrary.path),
        );

        expect(
          await resolveZstdLibraryPath(
            environment: const {},
            packageConfigs: const [],
          ),
          path.normalize(getZstdLibraryPath()),
        );

        expect(
          resolveZstdLibraryPath(
            environment: const {},
            packageConfigs: const [],
            executableDirectory: path.join(directory.path, 'empty-executable'),
            legacyPackageRoot: path.join(directory.path, 'empty-legacy'),
          ),
          throwsStateError,
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('rejects malformed and invalid package configurations', () async {
      final directory = await Directory.systemTemp.createTemp('zstd_config');
      try {
        final config = File(path.join(directory.path, 'package_config.json'));

        await config.writeAsString('{invalid');
        expect(await resolveZstdLibraryFromPackageConfig(config.uri), isNull);

        await config.writeAsString(jsonEncode(const []));
        expect(await resolveZstdLibraryFromPackageConfig(config.uri), isNull);

        await config.writeAsString(jsonEncode({'packages': const {}}));
        expect(await resolveZstdLibraryFromPackageConfig(config.uri), isNull);

        await config.writeAsString(
          jsonEncode({
            'packages': [
              {
                'name': 'zstandard_cli',
                'rootUri': 42,
                'packageUri': 'lib/',
              },
            ],
          }),
        );
        expect(await resolveZstdLibraryFromPackageConfig(config.uri), isNull);

        await config.writeAsString(
          jsonEncode({
            'packages': [
              {
                'name': 'zstandard_cli',
                'rootUri': 'https://example.invalid/package/',
                'packageUri': 'lib/',
              },
            ],
          }),
        );
        expect(await resolveZstdLibraryFromPackageConfig(config.uri), isNull);
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });

  group('Zstandard CLI tests', () {
    test(
      'getPlatformVersion returns non-null string on supported platform',
      () async {
        if (skipPlatform) return;
        final cli = ZstandardCLI();
        final version = await cli.getPlatformVersion();
        expect(version, isNotNull);
        expect(version, isNotEmpty);
      },
      skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false,
    );

    test('getPlatformVersion starts with platform name', () async {
      if (skipPlatform) return;
      final cli = ZstandardCLI();
      final version = await cli.getPlatformVersion();
      if (Platform.isMacOS) {
        expect(version, startsWith('macOS '));
      } else if (Platform.isWindows) {
        expect(version, startsWith('Windows '));
      } else if (Platform.isLinux) {
        expect(version, startsWith('Linux '));
      }
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test(
      'getZstdLibraryPath returns path with lib/src/bin and platform extension',
      () {
        if (skipPlatform) return;
        final libPath = getZstdLibraryPath();
        expect(libPath, contains('lib'));
        expect(libPath, contains('src'));
        expect(libPath, contains('bin'));
        if (Platform.isWindows) {
          expect(libPath, endsWith('.dll'));
          expect(libPath, anyOf(contains('arm64'), contains('x64')));
        } else if (Platform.isMacOS) {
          expect(libPath, endsWith('.dylib'));
        } else if (Platform.isLinux) {
          expect(libPath, endsWith('.so'));
          expect(libPath, anyOf(contains('arm64'), contains('x64')));
        }
      },
      skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false,
    );

    test(
      'resolveZstdLibraryPath is independent of the working directory',
      () async {
        if (skipPlatform) return;
        final originalDirectory = Directory.current;
        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'zstd_loader_test',
        );
        try {
          Directory.current = temporaryDirectory;
          final libraryPath = await resolveZstdLibraryPath();
          expect(File(libraryPath).existsSync(), isTrue);
        } finally {
          Directory.current = originalDirectory;
          await temporaryDirectory.delete(recursive: true);
        }
      },
      skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false,
    );

    test(
      'native library exports the complete supported symbol surface',
      () async {
        final library = DynamicLibrary.open(await resolveZstdLibraryPath());
        for (final symbol in <String>[
          'ZSTD_compress',
          'ZSTD_decompress',
          'ZSTD_compressBound',
          'ZSTD_getFrameContentSize',
          'ZSTD_isError',
          'ZSTD_createDStream',
          'ZSTD_initDStream',
          'ZSTD_decompressStream',
          'ZSTD_freeDStream',
          'ZSTD_DStreamOutSize',
        ]) {
          expect(
            () => library.lookup<NativeFunction<Void Function()>>(symbol),
            returnsNormally,
            reason: '$symbol must be exported by the bundled library',
          );
        }
      },
      skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false,
    );

    test('ZstandardCLI can be instantiated on supported platform', () {
      if (skipPlatform) return;
      expect(ZstandardCLI(), isA<ZstandardCLI>());
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);
    test('Compress and decompress small Uint8List', () async {
      final Uint8List sample = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress large Uint8List', () async {
      final Uint8List sample = Uint8List.fromList(
        List<int>.generate(100000, (i) => i % 256),
      );
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress empty Uint8List', () async {
      final Uint8List sample = Uint8List(0);
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(compressed, isNotNull);
      expect(compressed, isNotEmpty);
      expect(decompressed, equals(sample));
    });

    test('decompresses frames without a declared content size', () async {
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
      final result = await ZstandardCLI().decompress(
        Uint8List.fromList(frameWithoutContentSize),
      );
      expect(result, equals('unknown-size frame'.codeUnits));
    });

    test('decompression respects the configured output limit', () async {
      final cli = ZstandardCLI();
      final compressed = await cli.compress(Uint8List(1024));
      expect(compressed, isNotNull);
      expect(await cli.decompress(compressed!, maxOutputSize: 1023), isNull);
    });

    test('decompresses concatenated frames', () async {
      final cli = ZstandardCLI();
      final first = await cli.compress(Uint8List.fromList([1, 2, 3]));
      final second = await cli.compress(Uint8List.fromList([4, 5, 6]));
      final frames = Uint8List.fromList([...first!, ...second!]);
      expect(await cli.decompress(frames), equals([1, 2, 3, 4, 5, 6]));
    });

    test('Compress and decompress Uint8List with repeated values', () async {
      final Uint8List sample = Uint8List.fromList(List.filled(1000, 42));
      final compressed = await sample.compress(compressionLevel: 3);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress with maximum compression level', () async {
      final Uint8List sample = Uint8List.fromList([
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
      ]);
      final compressed = await sample.compress(compressionLevel: 22);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test('Compress and decompress with minimal compression level', () async {
      final Uint8List sample = Uint8List.fromList([
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
      ]);
      final compressed = await sample.compress(compressionLevel: 1);
      final decompressed = await compressed.decompress();
      expect(sample, isNot(equals(compressed)));
      expect(sample.length, isNot(equals(compressed?.length)));
      expect(decompressed, equals(sample));
    });

    test(
      'Compress with level 22 produces valid decompressible output',
      () async {
        final Uint8List sample = Uint8List.fromList(List.filled(500, 7));
        final compressed = await sample.compress(compressionLevel: 22);
        expect(compressed, isNotNull);
        final decompressed = await compressed!.decompress();
        expect(decompressed, equals(sample));
      },
    );

    test('invalid compression levels return null', () async {
      final cli = ZstandardCLI();
      expect(await cli.compress(Uint8List(1), compressionLevel: 0), isNull);
      expect(await cli.compress(Uint8List(1), compressionLevel: 23), isNull);
    });

    test('truncated frame returns null', () async {
      final cli = ZstandardCLI();
      final compressed = await cli.compress(Uint8List.fromList([1, 2, 3]));
      expect(compressed, isNotNull);
      expect(
        await cli.decompress(
          Uint8List.sublistView(compressed!, 0, compressed.length - 1),
        ),
        isNull,
      );
    });

    test('an exact decompression output limit succeeds', () async {
      final cli = ZstandardCLI();
      final input = Uint8List(1024);
      final compressed = await cli.compress(input);
      expect(
        await cli.decompress(compressed!, maxOutputSize: input.length),
        equals(input),
      );
    });

    test('Null extension receiver returns null from compress', () async {
      const Uint8List? nullData = null;
      final result = await nullData.compress();
      expect(result, isNull);
    });

    test('Null extension receiver returns null from decompress', () async {
      const Uint8List? nullData = null;
      final result = await nullData.decompress();
      expect(result, isNull);
    });

    test('decompress corrupted data returns null', () async {
      if (skipPlatform) return;
      final corrupted = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final cli = ZstandardCLI();
      final result = await cli.decompress(corrupted);
      expect(result, isNull);
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('decompress random bytes returns null', () async {
      if (skipPlatform) return;
      final random = Uint8List.fromList(
        List.generate(64, (i) => (i * 31) % 256),
      );
      final cli = ZstandardCLI();
      final result = await cli.decompress(random);
      expect(result, isNull);
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('compress and decompress do not leak', () async {
      if (skipPlatform) return;
      final cli = ZstandardCLI();
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final compressed = await cli.compress(data, compressionLevel: 3);
      expect(compressed, isNotNull);
      final decompressed = await cli.decompress(compressed!);
      expect(decompressed, equals(data));
      if (LeakTracking.isStarted) {
        final leaks = await LeakTracking.collectLeaks();
        expect(leaks, isLeakFree);
      }
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('file roundtrip: write, compress, decompress, compare', () async {
      if (skipPlatform) return;
      final tempDir = await Directory.systemTemp.createTemp('zstd_cli_test');
      final file = File('${tempDir.path}/input.bin');
      final data = Uint8List.fromList(List.generate(500, (i) => i % 256));
      await file.writeAsBytes(data);
      final cli = ZstandardCLI();
      final compressed = await cli.compress(data, compressionLevel: 3);
      expect(compressed, isNotNull);
      final compressedFile = File('${tempDir.path}/output$extension');
      await compressedFile.writeAsBytes(compressed!);
      final readBack = await compressedFile.readAsBytes();
      final decompressed = await cli.decompress(Uint8List.fromList(readBack));
      expect(decompressed, equals(data));
      await tempDir.delete(recursive: true);
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test(
      'extensionless CLI input is decompressed to a distinct .out file',
      () async {
        if (skipPlatform) return;
        final directory = await Directory.systemTemp.createTemp(
          'zstd_cli_output',
        );
        try {
          final original = Uint8List.fromList([9, 8, 7, 6]);
          final compressed = await ZstandardCLI().compress(original);
          final input = File('${directory.path}/payload');
          await input.writeAsBytes(compressed!);

          expect(await runDecompressCommand([input.path]), 0);
          expect(await input.readAsBytes(), equals(compressed));
          expect(
            await File('${input.path}.out').readAsBytes(),
            equals(original),
          );
        } finally {
          await directory.delete(recursive: true);
        }
      },
      skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false,
    );

    test(
      'CLI returns a usage error instead of replacing an existing output',
      () async {
        if (skipPlatform) return;
        final directory = await Directory.systemTemp.createTemp(
          'zstd_cli_force',
        );
        try {
          final input = File('${directory.path}/input.bin');
          final output = File('${directory.path}/output.zstd');
          await input.writeAsBytes([1, 2, 3]);
          await output.writeAsBytes([99]);

          expect(
            await runCompressCommand([input.path, '--output', output.path]),
            2,
          );
          expect(await output.readAsBytes(), equals([99]));
        } finally {
          await directory.delete(recursive: true);
        }
      },
      skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false,
    );

    test(
      'CLI validates arguments without loading the native library',
      () async {
        expect(await runCompressCommand([]), 2);
        expect(await runCompressCommand(['--level', '0', 'input']), 2);
        expect(
          await runDecompressCommand(['--max-output-size', '0', 'input']),
          2,
        );
        expect(await runCompressCommand(['--help']), 0);
        expect(await runDecompressCommand(['--version']), 0);
      },
    );

    test('CLI stdin and stdout form a binary-clean roundtrip', () async {
      if (skipPlatform) return;
      final directory = await Directory.systemTemp.createTemp('zstd_cli_pipe');
      try {
        final input = Uint8List.fromList(List<int>.generate(256, (i) => i));
        final compressedFile = File('${directory.path}/compressed');
        final compressedSink = compressedFile.openWrite();
        expect(
          await runCompressCommand(
            ['-'],
            standardInput: Stream<List<int>>.value(input),
            standardOutput: compressedSink,
          ),
          0,
        );
        await compressedSink.close();

        final restoredFile = File('${directory.path}/restored');
        final restoredSink = restoredFile.openWrite();
        expect(
          await runDecompressCommand(
            ['-'],
            standardInput: Stream<List<int>>.value(
              await compressedFile.readAsBytes(),
            ),
            standardOutput: restoredSink,
          ),
          0,
        );
        await restoredSink.close();
        expect(await restoredFile.readAsBytes(), equals(input));
      } finally {
        await directory.delete(recursive: true);
      }
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('CLI always refuses to overwrite its input', () async {
      if (skipPlatform) return;
      final directory = await Directory.systemTemp.createTemp('zstd_cli_alias');
      try {
        final input = File('${directory.path}/input.bin');
        await input.writeAsBytes([1, 2, 3]);
        expect(
          await runCompressCommand([
            input.path,
            '--output',
            input.path,
            '--force',
          ]),
          2,
        );
        expect(await input.readAsBytes(), equals([1, 2, 3]));
      } finally {
        await directory.delete(recursive: true);
      }
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('CLI reports every invalid argument form as a usage error', () async {
      final directory = await Directory.systemTemp.createTemp('zstd_cli_args');
      final errors = File(path.join(directory.path, 'stderr')).openWrite();
      try {
        expect(
          await runCompressCommand(['--output'], standardError: errors),
          2,
        );
        expect(
          await runCompressCommand(
            ['--level', 'not-an-integer', 'input'],
            standardError: errors,
          ),
          2,
        );
        expect(
          await runDecompressCommand(
            ['--max-output-size', 'not-an-integer', 'input'],
            standardError: errors,
          ),
          2,
        );
        expect(
          await runCompressCommand(
            ['--unknown', 'input'],
            standardError: errors,
          ),
          2,
        );
        expect(
          await runCompressCommand(
            ['first', 'second'],
            standardError: errors,
          ),
          2,
        );
        expect(
          await runCompressCommand(
            ['--', '--literal-missing-file'],
            standardError: errors,
          ),
          1,
        );
      } finally {
        await errors.close();
        await directory.delete(recursive: true);
      }
    });

    test('CLI converts codec, filesystem, and stream failures to exit code 1',
        () async {
      if (skipPlatform) return;
      final directory = await Directory.systemTemp.createTemp('zstd_cli_error');
      final errors = File(path.join(directory.path, 'stderr')).openWrite();
      try {
        final invalidInput = File(path.join(directory.path, 'invalid.zstd'));
        await invalidInput.writeAsBytes([1, 2, 3, 4]);
        expect(
          await runDecompressCommand(
            [invalidInput.path],
            standardError: errors,
          ),
          1,
        );
        expect(
          await runCompressCommand(
            [path.join(directory.path, 'missing')],
            standardError: errors,
          ),
          1,
        );
        expect(
          await runCompressCommand(
            ['-'],
            standardInput: Stream<List<int>>.error(StateError('read failed')),
            standardError: errors,
          ),
          1,
        );
      } finally {
        await errors.close();
        await directory.delete(recursive: true);
      }
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('CLI strips the zstd extension for the default decompressed output',
        () async {
      if (skipPlatform) return;
      final directory =
          await Directory.systemTemp.createTemp('zstd_cli_suffix');
      final errors = File(path.join(directory.path, 'stderr')).openWrite();
      try {
        final original = Uint8List.fromList([4, 8, 15, 16, 23, 42]);
        final compressed = await ZstandardCLI().compress(original);
        final input = File(path.join(directory.path, 'payload$extension'));
        await input.writeAsBytes(compressed!);

        expect(
          await runDecompressCommand([input.path], standardError: errors),
          0,
        );
        expect(
          await File(path.join(directory.path, 'payload')).readAsBytes(),
          original,
        );
      } finally {
        await errors.close();
        await directory.delete(recursive: true);
      }
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);

    test('multiple compressions in parallel', () async {
      if (skipPlatform) return;
      final cli = ZstandardCLI();
      final futures = List.generate(5, (i) {
        final data = Uint8List.fromList(
          List.generate(200, (j) => (i + j) % 256),
        );
        return cli.compress(data, compressionLevel: 3);
      });
      final results = await Future.wait(futures);
      expect(results.every((r) => r != null), isTrue);
      for (var i = 0; i < results.length; i++) {
        final decompressed = await cli.decompress(results[i]!);
        final original = Uint8List.fromList(
          List.generate(200, (j) => (i + j) % 256),
        );
        expect(decompressed, equals(original));
      }
    }, skip: skipPlatform ? 'Only runs on macOS, Windows, or Linux' : false);
  });
}
