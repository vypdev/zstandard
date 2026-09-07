[![pub package](https://img.shields.io/pub/v/zstandard_platform_interface.svg)](https://pub.dev/packages/zstandard_platform_interface)

# zstandard_platform_interface

A common platform interface for the [`zstandard`][1] plugin.

This interface allows platform-specific implementations of the `zstandard`
plugin, as well as the plugin itself, to ensure they are supporting the
same interface.

# Usage

To implement a new platform-specific implementation of `zstandard`, extend
[`ZstandardPlatform`][2] with an implementation that performs the
platform-specific behavior, and when you register your plugin, set the default
`ZstandardPlatform` by calling
`ZstandardPlatform.instance = MyPlatformZstandard()`.

Implementations that can enforce a decompressed-output budget should also
implement `BoundedZstandardPlatform`. The main package detects this optional
capability while preserving source compatibility for existing third-party
implementations of `ZstandardPlatform`.

# Note on breaking changes

Strongly prefer non-breaking changes (such as adding a method to the interface)
over breaking changes for this package.

See https://flutter.dev/go/platform-interface-breaking-changes for a discussion
on why a less-clean interface is preferable to a breaking change.

[1]: ../zstandard
[2]: lib/zstandard_platform_interface.dart
