# Security Policy

## Supported versions

We release security fixes for the latest stable major version. Older major versions may receive fixes on a best-effort basis.

## Reporting a vulnerability

Please report security issues **privately**. Do not open a public issue.

- **Email**: Prefer contacting the maintainers through the repository owner (e.g. via GitHub organization or the contact listed on [pub.dev](https://pub.dev/packages/zstandard)).
- **What to include**: Description of the issue, steps to reproduce, affected versions, and impact if possible.
- **Response**: We aim to acknowledge within a few days and will work with you on a fix and disclosure timeline.

## Security practices in this repository

- **Supply chain**: Release workflow pins GitHub Actions to full commit SHAs and pins the external `facebook/zstd` dependency to a specific ref (`ZSTD_REF` in `.github/workflows/release_workflow.yml`).
- **Pub.dev**: Publishing uses credentials from `dart pub login` on each self-hosted runner (standard Dart config locations). Keep runner access and credentials under control; rotate or re-login when needed.
- **Permissions**: CI jobs request minimal `permissions` (e.g. `contents: read` by default; `contents: write` only where needed).
- **Self-hosted runners**: If you use self-hosted runners, keep them updated, isolated, and consider ephemeral runners where possible.

For usage-related security (input validation, untrusted data, memory), see [docs/guides/security.md](docs/guides/security.md).
