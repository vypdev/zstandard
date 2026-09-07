import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('committed web artifacts are synchronized and bounded', () async {
    final packageJavaScript = File('blob/zstd.js');
    final packageCore = File('blob/zstd_core.js');
    final packageWorker = File('blob/zstd_worker.js');
    final packageWasm = File('blob/zstd.wasm');
    final webExampleJavaScript = File('example/web/zstd.js');
    final webExampleCore = File('example/web/zstd_core.js');
    final webExampleWorker = File('example/web/zstd_worker.js');
    final webExampleWasm = File('example/web/zstd.wasm');
    final rootExampleJavaScript = File('../zstandard/example/web/zstd.js');
    final rootExampleCore = File('../zstandard/example/web/zstd_core.js');
    final rootExampleWorker = File('../zstandard/example/web/zstd_worker.js');
    final rootExampleWasm = File('../zstandard/example/web/zstd.wasm');

    for (final artifact in <File>[
      packageJavaScript,
      packageCore,
      packageWorker,
      packageWasm,
      webExampleJavaScript,
      webExampleCore,
      webExampleWorker,
      webExampleWasm,
      rootExampleJavaScript,
      rootExampleCore,
      rootExampleWorker,
      rootExampleWasm,
    ]) {
      expect(artifact.existsSync(), isTrue, reason: artifact.path);
      expect(artifact.lengthSync(), greaterThan(0), reason: artifact.path);
    }

    expect(
      await webExampleJavaScript.readAsBytes(),
      equals(await packageJavaScript.readAsBytes()),
    );
    expect(
      await rootExampleJavaScript.readAsBytes(),
      equals(await packageJavaScript.readAsBytes()),
    );
    expect(
      await webExampleCore.readAsBytes(),
      equals(await packageCore.readAsBytes()),
    );
    expect(
      await rootExampleCore.readAsBytes(),
      equals(await packageCore.readAsBytes()),
    );
    expect(
      await webExampleWorker.readAsBytes(),
      equals(await packageWorker.readAsBytes()),
    );
    expect(
      await rootExampleWorker.readAsBytes(),
      equals(await packageWorker.readAsBytes()),
    );
    expect(
      await webExampleWasm.readAsBytes(),
      equals(await packageWasm.readAsBytes()),
    );
    expect(
      await rootExampleWasm.readAsBytes(),
      equals(await packageWasm.readAsBytes()),
    );

    final client = await packageJavaScript.readAsString();
    final core = await packageCore.readAsString();
    expect(client, contains('new Worker(workerUrl)'));
    expect(client, contains('[inputCopy.buffer]'));
    expect(core, contains('Module._ZSTD_decompressStream'));
    expect(core, contains('Module._ZSTD_createDStream'));
    expect(core, contains('maxOutputSize = 256 * 1024 * 1024'));
    expect(core, isNot(contains('compressedData.length * 20')));
  });
}
