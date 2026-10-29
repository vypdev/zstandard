"""Exercise the production Gradle resolver with real, host-native file URIs."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from urllib.parse import quote


def verify(gradle, plugin, native, stage, report):
    cases = []
    cache = stage / 'Pub cache/hosted/pub.dev'
    selected_package = cache / 'zstandard_native-9.8.7 é'
    # Both versions coexist in the same fixture cache. The source bytes come
    # from the candidate; these fixture version names are never published.
    shutil.copytree(native / 'src', selected_package / 'src')
    native = selected_package

    def sources(directory):
        root = directory / 'src/zstd'
        for part in ['common', 'compress', 'decompress']:
            (root / part).mkdir(parents=True, exist_ok=True)
        (root / 'zstd.h').touch()
        return root

    def configuration(consumer, entries):
        path = consumer / '.dart_tool/package_config.json'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({'configVersion': 2, 'packages': entries}), encoding='utf-8')
        return path

    def entry(uri):
        return {'name': 'zstandard_native', 'rootUri': uri, 'packageUri': 'lib/'}

    def case(name, consumer, expected=None, error=None, explicit=None, plugin_directory=plugin):
        consumer.mkdir(parents=True, exist_ok=True)
        cases.append({'name': name, 'consumer': str(consumer), 'plugin': str(plugin_directory),
                      'expected': str(expected) if expected else None,
                      'error': error, 'explicit': str(explicit) if explicit is not None else None})

    selected = native / 'src/zstd'
    decoy = sources(cache / 'zstandard_native-9.8.8')
    repository = stage / 'repository'
    sibling = sources(repository / 'zstandard_native')
    repository_plugin = repository / 'zstandard_android/android'
    repository_plugin.mkdir(parents=True)

    absolute = stage / 'separate consumer é/absolute'
    configuration(absolute, [entry(native.as_uri() + '/')])
    case('absolute file URI, exact selected version, spaces and Unicode', absolute / 'android', selected)

    relative = stage / 'separate consumer é/relative'
    config = relative / '.dart_tool/package_config.json'
    uri = quote(os.path.relpath(native, config.parent).replace(os.sep, '/'), safe='/') + '/'
    configuration(relative, [entry(uri)])
    case('relative URI is relative to package_config, not Gradle or plugin', relative / 'android', selected)

    workspace = stage / 'workspace with spaces'
    configuration(workspace, [entry(native.as_uri() + '/')])
    case('workspace ancestor configuration', workspace / 'apps/mobile/android', selected)

    case('explicit override precedes configured dependency', absolute / 'android', decoy, explicit=decoy)
    explicit_relative = os.path.relpath(decoy, absolute / 'android')
    case('relative explicit override uses consumer directory', absolute / 'android', decoy,
         explicit=explicit_relative)
    case('invalid explicit override fails without fallback', absolute / 'android',
         error='explicit ZSTD_ROOT', explicit=stage / 'missing')
    case('direct repository fallback without package configuration', repository / 'consumer/android',
         sibling, plugin_directory=repository_plugin)

    bad = [
        ('missing native dependency', [], 'Expected exactly one'),
        ('duplicate native dependencies', [entry(native.as_uri()), entry(decoy.parent.parent.as_uri())], 'Expected exactly one'),
        ('empty URI', [entry('')], 'Expected exactly one'),
        ('non-string URI', [entry(42)], 'Expected exactly one'),
        ('non-file URI', [entry('https://example.invalid/native')], 'Cannot resolve'),
        ('malformed URI', [entry('file:///%invalid')], 'Cannot resolve'),
        ('missing selected sources', [entry((stage / 'missing package').as_uri())], 'zstd source not found'),
    ]
    for index, (name, entries, message) in enumerate(bad):
        consumer = stage / f'invalid cases/{index}'
        configuration(consumer, entries)
        case(name + ' cannot select a cached or repository fallback', consumer / 'android',
             error=message, plugin_directory=repository_plugin)

    malformed = stage / 'malformed JSON'
    config = configuration(malformed, [])
    config.write_text('{bad JSON', encoding='utf-8')
    case('malformed JSON reports pub get guidance', malformed / 'android', error='Cannot read')
    invalid_shape = stage / 'invalid JSON shape'
    config = configuration(invalid_shape, [])
    config.write_text('{"packages": {}}', encoding='utf-8')
    case('invalid package configuration shape', invalid_shape / 'android', error='Invalid package configuration')

    project = stage / 'resolver verification'
    project.mkdir()
    (project / 'settings.gradle').write_text("rootProject.name = 'native-source-verification'\n", encoding='utf-8')
    (project / 'cases.json').write_text(json.dumps(cases), encoding='utf-8')
    (project / 'build.gradle').write_text('''import groovy.json.JsonSlurper
import groovy.json.JsonOutput
apply from: new File(new URI(RESOLVER_URI))
tasks.register('verifySources') {
    doLast {
        def cases = new JsonSlurper().parse(file('cases.json'), 'UTF-8')
        def results = []
        cases.each { item ->
            File resolved = null
            Exception failure = null
            try {
                resolved = resolveZstandardNativeRoot(new File(item.consumer), new File(item.plugin), item.explicit)
            } catch (Exception error) {
                failure = error
            }
            if (item.error) {
                assert failure != null : "${item.name}: unexpectedly succeeded"
                assert failure.message.contains(item.error) : "${item.name}: ${failure.message}"
            } else {
                assert failure == null : "${item.name}: ${failure}"
                assert resolved == new File(item.expected).canonicalFile : "${item.name}: selected ${resolved}"
            }
            println "PASS: ${item.name}"
            results.add([name: item.name, passed: true, root: resolved?.path])
        }
        file('results.json').text = JsonOutput.prettyPrint(JsonOutput.toJson(results))
    }
}
'''.replace('RESOLVER_URI', json.dumps((plugin / 'android/native_sources.gradle').as_uri())), encoding='utf-8')
    command = [str(gradle), '--no-daemon', '--offline', '--console=plain', '-p', str(project), 'verifySources']
    result = subprocess.run(command, capture_output=True, text=True, errors='replace', timeout=180)
    output = result.stdout + result.stderr
    (report / 'gradle-resolver.txt').write_text(output, encoding='utf-8')
    print(output[-10000:], flush=True)
    if result.returncode:
        raise RuntimeError('Production Gradle resolver regression checks failed.')
    results = json.loads((project / 'results.json').read_text(encoding='utf-8'))
    (report / 'gradle-resolver.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    resolved = Path(results[0]['root'])
    (report / 'selected-native-root.txt').write_text(resolved.as_posix(), encoding='utf-8')
    return resolved


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gradle', required=True, type=Path)
    parser.add_argument('--plugin', type=Path, default=Path(__file__).resolve().parents[1] / 'zstandard_android')
    parser.add_argument('--native', type=Path, default=Path(__file__).resolve().parents[1] / 'zstandard_native')
    parser.add_argument('--report-directory', required=True, type=Path)
    arguments = parser.parse_args()
    arguments.report_directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='zstandard resolver é ',
                                     dir=os.environ.get('RUNNER_TEMP')) as temporary:
        verify(arguments.gradle, arguments.plugin.resolve(), arguments.native.resolve(),
               Path(temporary).resolve(), arguments.report_directory)
