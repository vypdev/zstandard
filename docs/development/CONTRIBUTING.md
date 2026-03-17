# Contributing to Zstandard

Thank you for your interest in contributing to the Zstandard Flutter plugin and CLI. This document outlines how to set up your environment, follow our standards, and submit changes.

## Code of Conduct

Be respectful and professional. We aim to maintain a welcoming environment for everyone.

## Getting Started

1. **Fork and clone** the repository.
2. **Set up your development environment** — see [Setup](setup.md).
3. **Create a branch** for your work: `git checkout -b feature/your-feature` or `fix/your-fix`.
4. **Make your changes** following our [Code Style](code-style.md) and [Testing](testing.md) guidelines.
5. **Run tests** for the packages you changed: see [Testing](testing.md).
6. **Commit** with clear messages (e.g. "Add compression level validation in platform interface").
7. **Push** and open a **Pull Request** against the default branch.

## What to Contribute

- **Bug fixes**: Ensure there is an issue or discussion, then submit a fix with tests if applicable.
- **New features**: Open an issue first to discuss the design and scope. For new platform support, see the architecture docs.
- **Documentation**: Fixes and improvements to docs in `docs/` and to dartdoc comments are always welcome.
- **Tests**: Adding or fixing tests is highly valued; see [Testing](testing.md).

## Pull Request Process

1. **Target branch**: Open PRs against the repository’s default branch (e.g. `master` or `main`).
2. **CI**: Ensure all relevant CI checks pass (lint, tests, build).
3. **Review**: Address review feedback from maintainers.
4. **Scope**: Keep PRs focused. Split large changes into smaller, reviewable PRs when possible.
5. **Changelog**: For user-facing changes, add an entry to `CHANGELOG.md` under "Unreleased" or the next version.

## Development Workflow

- **Building**: See [Building](building.md) for how to build the plugin and native code per platform.
- **Testing**: See [Testing](testing.md) for unit and integration test instructions.
- **Releases**: See [Release Process](release-process.md) for how versions are published.

## Package Structure

- **zstandard** — Main Flutter plugin; applications depend only on this.
- **zstandard_platform_interface** — Abstract platform contract.
- **zstandard_android, zstandard_ios, zstandard_macos, zstandard_linux, zstandard_windows, zstandard_web** — Platform implementations.
- **zstandard_cli** — Standalone Dart CLI package (no Flutter).

When changing the platform interface, ensure all platform implementations are updated and tests pass.

## Questions

- Open a [GitHub Issue](https://github.com/vypdev/zstandard/issues) for bugs or feature requests.
- Use [GitHub Discussions](https://github.com/vypdev/zstandard/discussions) for questions and ideas.

Thank you for contributing.
