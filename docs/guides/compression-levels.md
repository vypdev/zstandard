# Compression Levels

Zstandard supports compression levels from **1** to **22**. Higher levels give better compression ratio but are slower and use more memory.

## Summary

| Level | Speed    | Ratio   | Typical use              |
|-------|----------|---------|---------------------------|
| 1     | Fastest  | Lowest  | Real-time, low latency   |
| 3     | Fast     | Good    | **Default**; general use  |
| 5–9   | Medium   | Better  | Balanced                  |
| 10–19 | Slower   | High    | Storage, archival        |
| 20–22 | Slowest  | Highest | Maximum ratio             |

## Choosing a level

- **Default (3)**: Use when you don’t have special requirements. Good balance of speed and ratio.
- **Level 1**: When speed matters more than size (e.g. real-time or interactive).
- **Level 10–19**: When you care about size and can afford more CPU (e.g. backups, assets).
- **Level 22**: When you want the smallest output and time is not critical.

## In code

```dart
// Default (level 3) via extension
final c1 = await data.compress();

// Explicit level
final c2 = await data.compress(compressionLevel: 1);
final c3 = await zstandard.compress(data, 19);
```

## Notes

- Invalid levels (e.g. &lt; 1 or &gt; 22) may be accepted or rejected depending on the platform; stick to 1–22 for portability.
- Compression level does not affect decompression; decompression speed is largely independent of the level used to compress.
- For very small inputs, the compressed size may be larger than the input; level has limited impact there.

## See also

- [Performance tips](performance-tips.md)
- [API — Main](../api/main-api.md)
