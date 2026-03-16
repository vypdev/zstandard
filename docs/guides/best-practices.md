# Best Practices

This guide summarizes recommended practices, a production checklist, and common anti-patterns when using the Zstandard plugin and CLI.

## Do's

1. **Check for null** after every `compress` and `decompress` when the result is used. Null means failure; handle it (log, retry, or show an error).
2. **Use a valid compression level** (1–22). Clamp or validate user input to this range for portability.
3. **Reuse the Zstandard instance** — it is a singleton; no need to cache it yourself.
4. **Limit input size** when processing user or untrusted data to avoid excessive memory use and potential abuse.
5. **Prefer extension methods** when you have a single value: `data.compress()`, `compressed?.decompress()` for clearer null-aware code.
6. **Use chunking for large data** (see [Advanced usage](advanced-usage.md)) to control memory and keep the UI responsive.
7. **Choose the right level**: level 3 for general use; 1 for speed; 10+ for size when CPU and time allow.
8. **Validate decompressed content** when data comes from untrusted sources; the API only guarantees valid zstd output, not safe application-level content.
9. **Run tests and analyze** before release: `flutter test`, `flutter analyze` (or `dart test` / `dart analyze` for the CLI package).
10. **Pin package versions** in `pubspec.yaml` (e.g. `zstandard: ^1.3.0`) and update in a controlled way.

## Don'ts

1. **Don't ignore null results** — using a null result as if it were data can lead to crashes or wrong behaviour.
2. **Don't use compression levels outside 1–22** — behaviour is implementation-defined and may differ by platform.
3. **Don't decompress untrusted data without a size limit** — cap input size to what you are willing to allocate.
4. **Don't assume decompress throws** on invalid input — it typically returns null; handle null.
5. **Don't load entire very large files into memory** if you can avoid it; use chunked reading and compression.
6. **Don't run many concurrent compress/decompress operations** without limiting concurrency; memory usage can grow quickly.
7. **Don't rely on platform-specific behaviour** (e.g. specific error messages or edge-case handling); stick to the documented API and null semantics.
8. **Don't skip dependency updates** indefinitely; update periodically and run tests to catch breaking changes.

## Production checklist

Before shipping an app or script that uses zstandard:

- [ ] **Error handling**: All `compress`/`decompress` call sites check for null and handle failure.
- [ ] **Compression level**: Level is validated (1–22) when it comes from config or user input.
- [ ] **Input size**: Limits applied for user or untrusted data (e.g. max decompress size, max compress size).
- [ ] **Large data**: Very large payloads use chunking or size limits to avoid OOM.
- [ ] **Platforms**: App is tested on every platform you support (Android, iOS, web, etc.).
- [ ] **Dependencies**: `flutter pub get` / `dart pub get` and `flutter pub upgrade` run; no unexpected breakages.
- [ ] **Analytics or logging**: Null results or failures logged or reported where appropriate.
- [ ] **Security**: No sensitive data logged in raw form; untrusted data handled as in [Security](security.md).
- [ ] **Performance**: Compression level and chunk size chosen for your latency and memory constraints.

## Anti-patterns

**Ignoring null**

```dart
// Bad
final c = await z.compress(data, 3);
await send(c!);  // Can throw if compress failed

// Good
final c = await z.compress(data, 3);
if (c == null) return handleError();
await send(c);
```

**Unbounded decompression**

```dart
// Bad: no size limit on untrusted input
final d = await z.decompress(userBytes);

// Good: reject or cap size before calling
if (userBytes.length > maxDecompressSize) return reject();
final d = await z.decompress(userBytes);
```

**Assuming exceptions**

```dart
// Bad: decompress returns null on invalid data, does not throw
try {
  final d = await z.decompress(badBytes);
  use(d);  // d may be null
} catch (e) { ... }

// Good
final d = await z.decompress(badBytes);
if (d == null) return handleInvalid();
use(d);
```

**Unvalidated level**

```dart
// Bad
final level = int.parse(userInput);
await z.compress(data, level);

// Good
final level = int.parse(userInput).clamp(1, 22);
await z.compress(data, level);
```

## See also

- [Error handling](error-handling.md)
- [Security](security.md)
- [Advanced usage](advanced-usage.md)
- [Performance tips](performance-tips.md)
