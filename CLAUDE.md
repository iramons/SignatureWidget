# SignatureWidget

A SwiftUI app (iOS/macOS) that lets users draw and save handwritten signatures, then display them as home/lock screen widgets via WidgetKit.

## Project Structure

```
SignatureWidget/
├── SignatureWidget/          # Main app target
│   ├── SignatureWidgetApp.swift   # @main, SwiftData ModelContainer setup
│   ├── ContentView.swift          # Root list view + navigation
│   ├── SignatureEditorView.swift  # Drawing canvas (sheet)
│   ├── Signature.swift            # SwiftData model + Color<->Hex helpers
│   └── SignatureSharing.swift     # App Group write/delete/catalog logic
└── WidgetExtension/          # Widget target
    ├── WidgetExtension.swift      # Timeline provider, entry view, Widget declaration
    └── AppIntent.swift            # ConfigurationAppIntent, AppEntity, DTO types, WidgetCatalogLoader
```

## Architecture & Key Patterns

### Data Flow (App → Widget)
SwiftData cannot be shared between the app and the widget extension. Data sharing is done via an **App Group** (`group.br.com.devbrains.SignatureWidgets`) using plain JSON files on disk:

1. **Individual signature files**: `signature_<UUID>.json` — one per signature, contains all strokes.
2. **Catalog file**: `signatures_catalog.json` — lightweight index (UUID + createdAt) so the widget can list available signatures without loading all stroke data.

`SignatureSharing.swift` (app side) owns all write/delete/rebuild operations via `SignatureSharingWriter`. The widget reads via `WidgetCatalogLoader` (widget side) — these are intentionally separate to keep SwiftData out of the extension target.

### Model Layer
- `Signature` — `@Model` (SwiftData). Stores strokes as `[Stroke]`, colors as RGBA hex strings (`#RRGGBBAA`).
- `Stroke` — `Codable`, `Hashable`. Contains `[StrokePoint]` with normalized coordinates (0.0–1.0 relative to canvas size).
- `StrokePoint` — stores `x`, `y` normalized + timestamp `t`.

**Normalized coordinates** are key: all points are divided by canvas width/height on write, then multiplied back on render. This makes strokes resolution-independent across any widget/canvas size.

### Color Serialization
`Color` is not `Codable`. Colors are serialized as `#RRGGBBAA` hex strings via extensions in `Signature.swift` (`toHexRGBA()` / `fromHexRGBA(_:)`). Cross-platform: uses `UIColor` on iOS, `NSColor` on macOS.

### Widget Side DTOs
The widget target defines its own parallel structs (`WidgetSharedSignatureData`, `WidgetSharedStroke`, etc.) mirroring the app's `SharedSignature*` DTOs in `SignatureSharing.swift`. This avoids any dependency on SwiftData in the extension. Similarly, `WidgetStroke`/`WidgetStrokePoint` are lightweight widget-only types decoded from those DTOs.

### Drawing Canvas
`SignatureEditorView` uses SwiftUI `Canvas` + `DragGesture`. Points are normalized on capture (`point.x / size.width`). Undo removes the last stroke from `workingStrokes`. The canvas re-renders completely on every state change (stateless render from stroke array).

`SignatureCanvasReadonly` (app) and `SignatureCanvasReadonlyWidget` (widget) share the same rendering logic — iterate strokes, build `Path`, call `context.stroke(...)`.

### Widget Configuration
Uses `AppIntentConfiguration` with `ConfigurationAppIntent` (a `WidgetConfigurationIntent`). `SignatureChoice` is the `AppEntity` — the widget picker populates it from the catalog file at configuration time. If no signature is chosen, the widget defaults to the most recently created one.

Supported widget families: `.systemSmall/Medium/Large`, `.accessoryRectangular`, `.accessoryCircular`, `.accessoryInline`.

## Data Sync Responsibilities

| Action | Who calls what |
|---|---|
| New signature saved | `SignatureSharingWriter.writeSignature` + `rebuildCatalog` + `reloadWidgets` |
| Existing signature edited | `writeSignature` + `rebuildCatalog` + `reloadWidgets` |
| Signature deleted | `removeSignatureFile` + `rebuildCatalog` + `reloadWidgets` |
| App launch | `rebuildCatalog` (ensures catalog is consistent with SwiftData) |

`WidgetCenter.shared.reloadAllTimelines()` must be called after any change to push updates to the widget.

## Build Notes

- Both targets must have the same App Group capability: `group.br.com.devbrains.SignatureWidgets`.
- `WidgetExtensionExtension.entitlements` at the root is the widget's entitlements file (the path is a bit confusing — it's not inside the `WidgetExtension/` folder).
- The app uses `internal import UniformTypeIdentifiers` to scope UTType usage — this is intentional.
