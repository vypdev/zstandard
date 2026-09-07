# Vendored Zstandard provenance

The canonical native sources under `src/zstd/` come from the official
[`facebook/zstd`](https://github.com/facebook/zstd) repository.

- Base revision: `d7ee3207cc0db53f78fc6a69babc80747b1b7658`
- Reported library version: `1.5.7`
- Backported upstream fix:
  `3f8f9b3f89244638f10bca664c120fd28cb14efe` (guard a failed custom
  allocation before `memset`)
- Imported scope: upstream `lib/`, preserving this repository's
  `src/zstd/include/` SwiftPM bridge headers

`scripts/update_zstd.sh` uses the pinned base revision by default, applies the
backport when it is not already present, and records the resolved revision.
Review upstream release notes and security advisories before changing either
revision.
