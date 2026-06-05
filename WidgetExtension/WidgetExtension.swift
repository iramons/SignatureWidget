//
//  WidgetExtension.swift
//  WidgetExtension
//
//  Created by Ramon Santos on 16/11/25.
//

import WidgetKit
import SwiftUI

// MARK: - Tipos simples só para o Widget (evitam depender de SwiftData no Extension)
struct WidgetStrokePoint: Hashable {
    var x: CGFloat
    var y: CGFloat
}

struct WidgetStroke: Hashable, Identifiable {
    var id: UUID = UUID()
    var points: [WidgetStrokePoint]
    var color: Color = .primary
    var lineWidth: CGFloat = 4.0
}

// MARK: - Views equivalentes ao SignatureThumbnail/SignatureCanvasReadonly
struct SignatureCanvasReadonlyWidget: View {
    let strokes: [WidgetStroke]

    var body: some View {
        Canvas { context, size in
            for stroke in strokes {
                guard !stroke.points.isEmpty else { continue }
                var path = Path()
                let pts = stroke.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                if let first = pts.first {
                    path.move(to: first)
                    for p in pts.dropFirst() {
                        path.addLine(to: p)
                    }
                }
                context.stroke(path, with: .color(stroke.color), lineWidth: stroke.lineWidth)
            }
        }
        .aspectRatio(3, contentMode: .fit)
    }
}

struct SignatureThumbnailWidget: View {
    let strokes: [WidgetStroke]
    var body: some View {
        SignatureCanvasReadonlyWidget(strokes: strokes)
            .contentShape(Rectangle())
    }
}

// MARK: - Converter DTO -> Strokes do widget
func widgetStrokes(from shared: WidgetSharedSignatureData) -> [WidgetStroke] {
    shared.strokes.map { s in
        WidgetStroke(
            id: s.id,
            points: s.points.map { WidgetStrokePoint(x: $0.x, y: $0.y) },
            color: Color.fromHexRGBA(s.colorHex) ?? .primary,
            lineWidth: s.lineWidth
        )
    }
}

// MARK: - Timeline Provider
struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), strokes: [], configuration: ConfigurationAppIntent(), hasAccess: true)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let strokes = await loadStrokes(for: configuration)
        return SimpleEntry(date: Date(), strokes: strokes, configuration: configuration,
                           hasAccess: WidgetAccessChecker.hasAccess)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let access = WidgetAccessChecker.hasAccess
        let strokes = access ? await loadStrokes(for: configuration) : []
        let entry = SimpleEntry(date: Date(), strokes: strokes, configuration: configuration,
                                hasAccess: access)
        // Refresh every hour so trial expiry is noticed quickly
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private static let selectedUUIDKey = "selectedSignatureUUID"
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetCatalogLoader.appGroupID)
    }

    private func loadStrokes(for configuration: ConfigurationAppIntent) async -> [WidgetStroke] {
        do {
            // Resolve UUID: prefer explicit selection, then last known selection, then latest
            let resolvedUUID: UUID?
            if let chosen = configuration.signature {
                // Persist so future reloads survive entity re-resolution failures
                defaults?.set(chosen.id.uuidString, forKey: Self.selectedUUIDKey)
                resolvedUUID = chosen.id
            } else if let stored = defaults?.string(forKey: Self.selectedUUIDKey),
                      let uuid = UUID(uuidString: stored) {
                resolvedUUID = uuid
            } else {
                resolvedUUID = nil
            }

            if let uuid = resolvedUUID,
               let shared = try? await WidgetCatalogLoader.loadSignature(uuid: uuid) {
                return widgetStrokes(from: shared)
            }

            // Final fallback: most recently created signature
            let catalog = try await WidgetCatalogLoader.loadCatalog()
            if let latest = catalog.sorted(by: { $0.createdAt > $1.createdAt }).first {
                let shared = try await WidgetCatalogLoader.loadSignature(uuid: latest.uuid)
                return widgetStrokes(from: shared)
            }
        } catch {
            print("Provider.loadStrokes error:", error)
        }
        return []
    }
}

// MARK: - Access Checker (widget-side, reads from App Group)

enum WidgetAccessChecker {
    private static let appGroupID      = "group.br.com.devbrains.SignatureWidgets"
    private static let firstLaunchKey  = "com.signaturewidget.firstLaunchDate"
    private static let purchasedKey    = "com.signaturewidget.isPurchased"
    private static let trialDays       = 7

    static var hasAccess: Bool { isTrialActive || isPurchased }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static var isPurchased: Bool {
        defaults.bool(forKey: purchasedKey)
    }

    private static var isTrialActive: Bool {
        guard let launch = defaults.object(forKey: firstLaunchKey) as? Date else { return true }
        let elapsed = Calendar.current.dateComponents([.day], from: launch, to: Date()).day ?? 0
        return elapsed < trialDays
    }
}

// MARK: - Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let strokes: [WidgetStroke]
    let configuration: ConfigurationAppIntent
    let hasAccess: Bool
}

// MARK: - Entry View (adapta para Lock Screen e Home)
struct WidgetExtensionEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        if entry.hasAccess {
            signatureView
        } else {
            lockedView
        }
    }

    @ViewBuilder
    private var signatureView: some View {
        switch family {
        case .accessoryInline:
            Text("Signature")
        case .accessoryCircular:
            SignatureThumbnailWidget(strokes: entry.strokes).padding(2)
        case .accessoryRectangular:
            SignatureThumbnailWidget(strokes: entry.strokes).padding(4)
        default:
            SignatureThumbnailWidget(strokes: entry.strokes).padding(8)
        }
    }

    @ViewBuilder
    private var lockedView: some View {
        switch family {
        case .accessoryInline:
            Label("Subscribe", systemImage: "lock.fill")
        case .accessoryCircular:
            ZStack {
                Circle().fill(Color.gray.opacity(0.15))
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        default:
            ZStack {
                Color(.systemBackground).opacity(0.95)
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.indigo)
                    Text("Subscribe to continue")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Open the app")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Widget
struct WidgetExtension: Widget {
    let kind: String = "WidgetExtension"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: ConfigurationAppIntent.self,
                               provider: Provider()) { entry in
            WidgetExtensionEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Signature")
        .description("Shows your saved signature.")
        .supportedFamilies([
            .systemSmall,            // Home Screen
            .systemMedium,           // Home Screen (opcional)
            .systemLarge,            // Home Screen (opcional)
            .accessoryRectangular,   // Lock Screen
            .accessoryCircular,      // Lock Screen
            .accessoryInline         // Lock Screen (texto curto)
        ])
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    WidgetExtension()
} timeline: {
    SimpleEntry(date: .now, strokes: [], configuration: ConfigurationAppIntent(), hasAccess: true)
    SimpleEntry(date: .now, strokes: [], configuration: ConfigurationAppIntent(), hasAccess: false)
}
