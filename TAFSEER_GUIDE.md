# Tafseer Integration

MushafImad now includes comprehensive Tafseer (Quran commentary) support with import capabilities from JSON sources and intelligent caching mechanisms.

## Overview

The Tafseer feature allows users to:

- Import Tafseer data from JSON files
- View commentary for individual verses
- Cache Tafseer data for offline access
- Switch between multiple Tafseer sources
- Preload chapters for smooth navigation

## Architecture

### Data Models

#### `Tafseer`
Represents a Tafseer book/source with metadata:
```swift
public final class Tafseer: Object, Identifiable {
    @Persisted public var identifier: String  // e.g., "ibn-kathir"
    @Persisted public var name: String        // Arabic name
    @Persisted public var nameEnglish: String // English name
    @Persisted public var authorName: String
    @Persisted public var language: String    // "ar", "en", etc.
    @Persisted public var isDownloaded: Bool
    @Persisted public var isActive: Bool
}
```

#### `VerseTafseer`
Links Tafseer text to specific verses:
```swift
public final class VerseTafseer: Object, Identifiable {
    @Persisted public var identifier: String     // Composite key
    @Persisted public var tafseerId: String
    @Persisted public var chapterNumber: Int
    @Persisted public var verseNumber: Int
    @Persisted public var text: String          // Full commentary
    @Persisted public var shortText: String     // Abridged version
}
```

### Services

#### `TafseerImportService`
Handles importing Tafseer data from various sources:

```swift
// Import from local JSON file
let count = try await TafseerImportService.shared.importTafseer(from: fileURL)

// Import from remote URL
let count = try await TafseerImportService.shared.importTafseerFromRemote(remoteURL)

// Import bundled Tafseer data
let count = try await TafseerImportService.shared.importBundledTafseer()
```

#### `TafseerCacheService`
Manages caching for optimal performance:

```swift
// Configure cache settings
TafseerCacheService.shared.configure(with: .aggressive)

// Retrieve Tafseer text
let text = await TafseerCacheService.shared.getTafseer(
    tafseerId: "ibn-kathir",
    chapterNumber: 2,
    verseNumber: 255
)

// Preload a chapter for smooth navigation
await TafseerCacheService.shared.preloadChapter(
    tafseerId: "al-jalalayn",
    chapterNumber: 1
)
```

## JSON Data Format

Tafseer data files must follow this schema:

```json
{
  "tafseerId": "unique-identifier",
  "name": "Arabic Name",
  "nameEnglish": "English Name",
  "authorName": "Author Name",
  "authorNameEnglish": "Author Name English",
  "language": "ar",
  "verses": [
    {
      "tafseerId": "unique-identifier",
      "chapterNumber": 1,
      "verseNumber": 1,
      "text": "Full Tafseer text...",
      "shortText": "Brief summary (optional)"
    }
  ]
}
```

### Pre-included Tafseer Sources

The package includes sample data for:

- **Al-Jalalayn** (`al-jalalayn.json`) - Tafsir Al-Jalalayn by Imams Al-Mahalli & As-Suyuti
- **Ibn Kathir** (`ibn-kathir.json`) - Tafsir Ibn Kathir (sample verses)

## Usage Examples

### Basic Usage

```swift
import MushafImad

// Initialize Realm (required before using Tafseer)
try? RealmService.shared.initialize()

// Import bundled Tafseer
Task {
    let importedCount = try await TafseerImportService.shared.importBundledTafseer()
    print("Imported \(importedCount) verses")
}
```

### Displaying Tafseer

```swift
struct TafseerView: View {
    let chapterNumber: Int
    let verseNumber: Int
    @State private var tafseerText: String = ""
    
    var body: some View {
        ScrollView {
            Text(tafseerText)
                .padding()
        }
        .task {
            if let text = await TafseerCacheService.shared.getTafseer(
                tafseerId: "al-jalalayn",
                chapterNumber: chapterNumber,
                verseNumber: verseNumber
            ) {
                tafseerText = text
            }
        }
    }
}
```

### Switching Tafseer Sources

```swift
Task {
    // Set active Tafseer
    try await TafseerCacheService.shared.setActiveTafseer("ibn-kathir")
    
    // Get list of available Tafseers
    let availableTafseers = await TafseerCacheService.shared.getAvailableTafseerInfo()
}
```

### Preloading for Performance

```swift
Task {
    // Preload next chapter while user reads current chapter
    await TafseerCacheService.shared.preloadChapter(
        tafseerId: activeTafseerId,
        chapterNumber: nextChapter
    )
}
```

## Cache Configuration

Three preset configurations are available:

```swift
// Default: Balanced caching
TafseerCacheService.shared.configure(with: .default)

// Aggressive: Large memory cache for heavy usage
TafseerCacheService.shared.configure(with: .aggressive)

// Minimal: Minimal memory usage
TafseerCacheService.shared.configure(with: .minimal)
```

Or create a custom configuration:

```swift
let config = TafseerCacheService.CacheConfiguration(
    maxMemoryCacheSize: 2000,
    enableDiskCache: true,
    enableMemoryCache: true
)
TafseerCacheService.shared.configure(with: config)
```

## API Reference

### Predefined Tafseer Sources

```swift
public enum TafseerSource: String, CaseIterable {
    case ibnKathir = "ibn-kathir"
    case alJalalayn = "al-jalalayn"
    case alSaadi = "al-saadi"
    case alTabari = "al-tabari"
    case alBaghawi = "al-baghawi"
    case alQurtubi = "al-qurtubi"
}
```

### RealmService Extensions

```swift
extension RealmService {
    public func getTafseer(identifier: String) -> Tafseer?
    public func getAllTafseers() -> Results<Tafseer>?
    public func getActiveTafseer() -> Tafseer?
    public func getVerseTafseer(tafseerId: String, chapterNumber: Int, verseNumber: Int) -> VerseTafseer?
    public func isTafseerDownloaded(identifier: String) -> Bool
}
```

## Error Handling

```swift
do {
    let count = try await TafseerImportService.shared.importTafseer(from: url)
} catch TafseerImportError.realmNotInitialized {
    // Initialize Realm first
} catch TafseerImportError.invalidJSON {
    // Handle invalid JSON format
} catch {
    // Handle other errors
}
```

## Contributing Tafseer Data

To add a new Tafseer source:

1. Create a JSON file following the schema above
2. Place it in `Sources/MushafImad/Resources/Res/tafseer/`
3. The file will be automatically bundled with the package
4. Users can import it using `importBundledTafseer()`

## Performance Considerations

- Tafseer data is stored in the same Realm database as Quran data
- Memory cache uses LRU (Least Recently Used) eviction policy
- Consider preloading adjacent chapters for smooth navigation
- Full-text Tafseer can be large; use `shortText` for previews

## License

The Tafseer feature follows the same MIT license as MushafImad. Ensure you have proper rights to distribute any Tafseer texts you include.
