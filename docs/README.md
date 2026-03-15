# Zstandard Documentation

Welcome to the Zstandard Flutter plugin documentation. This directory contains comprehensive guides, API references, and development documentation for the zstandard compression ecosystem.

## Documentation Index

### Architecture

- [Overview](architecture/overview.md) — High-level architecture and federated plugin design
- [Platform Interface](architecture/platform-interface.md) — Interface contract and platform abstraction
- [FFI Implementation](architecture/ffi-implementation.md) — Native FFI pattern for mobile and desktop
- [Web Implementation](architecture/web-implementation.md) — WebAssembly and JS interop approach
- [Isolate Pattern](architecture/isolate-pattern.md) — Async compression with isolates

### API Reference

- [Main API](api/main-api.md) — Zstandard class and public API
- [Extensions](api/extensions.md) — ZstandardExt extension methods
- [Platform Interface API](api/platform-interface.md) — Platform contract reference
- [CLI API](api/cli-api.md) — zstandard_cli package API

### Guides

- [Getting Started](guides/getting-started.md) — Quick start guide
- [Installation](guides/installation.md) — Platform-specific setup
- [Usage Examples](guides/usage-examples.md) — Real-world examples
- [Compression Levels](guides/compression-levels.md) — Performance vs ratio guide
- [Error Handling](guides/error-handling.md) — Error scenarios and recovery
- [Performance Tips](guides/performance-tips.md) — Optimization guide
- [Migration Guide](guides/migration-guide.md) — Version migration

### Platform-Specific

- [Android](platforms/android.md)
- [iOS](platforms/ios.md)
- [macOS](platforms/macos.md)
- [Windows](platforms/windows.md)
- [Linux](platforms/linux.md)
- [Web](platforms/web.md)
- [CLI](platforms/cli.md)

### Development

- [Contributing](development/CONTRIBUTING.md) — Contribution guidelines
- [Setup](development/setup.md) — Development environment
- [Building](development/building.md) — Build instructions
- [Testing](development/testing.md) — Testing guidelines
- [Code Style](development/code-style.md) — Coding standards
- [Release Process](development/release-process.md) — Release workflow

### Troubleshooting

- [Common Issues](troubleshooting/common-issues.md) — FAQ and solutions
- [Platform Issues](troubleshooting/platform-issues.md) — Platform-specific issues
- [Debugging](troubleshooting/debugging.md) — Debug techniques

## Package Overview

| Package | Description |
|---------|-------------|
| [zstandard](https://pub.dev/packages/zstandard) | Main Flutter plugin for cross-platform compression |
| [zstandard_cli](https://pub.dev/packages/zstandard_cli) | Pure Dart CLI for macOS, Windows, and Linux |
| [zstandard_platform_interface](https://pub.dev/packages/zstandard_platform_interface) | Platform interface contract |
| zstandard_android, zstandard_ios, zstandard_macos | Mobile and macOS implementations |
| zstandard_linux, zstandard_windows | Desktop implementations |
| zstandard_web | Web (WebAssembly) implementation |
