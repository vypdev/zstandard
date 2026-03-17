# Code Style

This document describes the coding standards for the Zstandard project. Following these keeps the codebase consistent and maintainable.

## Dart / Flutter Conventions

- Follow the [official Dart style guide](https://dart.dev/guides/language/effective-dart/style).
- Use **flutter_lints** (or the project’s chosen lint set) and fix all reported issues. The project’s `pubspec.yaml` files typically include `flutter_lints: ^5.0.0` under `dev_dependencies`.
- Run `dart analyze` or `flutter analyze` from the package directory and fix analyzer warnings and errors.

## Formatting

- Use `dart format` (or `dart format .` in each package) to format code. The project may use a line length of 80 characters; match the existing code.
- Format before committing. Many projects enable format-on-save in the IDE.

## Naming

- **Classes**: `PascalCase` (e.g. `ZstandardPlatform`, `ZstandardLinux`).
- **Libraries and files**: `snake_case` (e.g. `zstandard_platform_interface.dart`, `zstandard_impl_native.dart`).
- **Variables, parameters, methods**: `camelCase` (e.g. `compressionLevel`, `getPlatformVersion`).
- **Constants**: `camelCase` or `lowerCamelCase` for const variables (e.g. `_token`, `_libName`). Use `lowerCamelCase` for const values that are not private.

## Documentation

- Add **dartdoc** comments to all public APIs (classes, methods, parameters, return values). See the plan’s dartdoc task and the [API docs](../api/main-api.md).
- Use `///` for documentation comments. Include a brief summary, parameter and return descriptions, and mention exceptions or null when relevant.
- Prefer linking to related APIs with `[ClassName]` or `[methodName]`.

## Error Handling

- Prefer returning `null` for recoverable failures (e.g. compress/decompress failure) when the API returns `Uint8List?`.
- Use `UnimplementedError` in abstract or default platform implementations for methods that must be overridden.
- Avoid swallowing errors; log or rethrow when appropriate, and document possible exceptions in dartdoc.

## Imports

- Order imports: Dart SDK, Flutter, then third-party packages, then project packages. Use alphabetical order within each group if the project does.
- Use `package:` imports for project packages (e.g. `package:zstandard_platform_interface/zstandard_platform_interface.dart`).

## Platform and FFI Code

- In FFI code, always free allocated memory in a `finally` block (or use the same pattern the project uses) to avoid leaks.
- Use the project’s existing patterns for opening the native library and for calling into C (e.g. generated bindings, error checking).

## Tests

- Use descriptive `group()` and `test()` names (e.g. `'compress and decompress roundtrip for large data'`).
- Prefer `setUp()` and `tearDown()` for shared initialization and cleanup.
- Mock the platform in unit tests rather than depending on a real native implementation when testing plugin logic.

## Commit Messages

- Use clear, imperative messages (e.g. "Add compression level validation", "Fix memory leak in Linux decompress").
- Reference issues when applicable (e.g. "Fix #123: null check in extension").

Consistency with the existing codebase takes precedence when the style guide is silent; when in doubt, match surrounding code.
