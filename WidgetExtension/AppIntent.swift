//
//  AppIntent.swift
//  WidgetExtension
//
//  Created by Ramon Santos on 16/11/25.
//

import WidgetKit
import AppIntents
import Foundation
import SwiftUI
internal import UniformTypeIdentifiers

// MARK: - AppEntity que representa uma assinatura disponível
struct SignatureChoice: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Signature")

    static var defaultQuery = SignatureChoiceQuery()

    let id: UUID
    let createdAt: Date

    var displayRepresentation: DisplayRepresentation {
        let dateStr = DateFormatter.localizedString(from: createdAt, dateStyle: .short, timeStyle: .short)
        return DisplayRepresentation(title: "\(dateStr)")
    }
}

struct SignatureChoiceQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [SignatureChoice] {
        let catalog = try await WidgetCatalogLoader.loadCatalog()
        let map = Dictionary(uniqueKeysWithValues: catalog.map { ($0.uuid, $0) })
        return identifiers.compactMap { id in
            guard let item = map[id] else { return nil }
            return SignatureChoice(id: item.uuid, createdAt: item.createdAt)
        }
    }

    func suggestedEntities() async throws -> [SignatureChoice] {
        let catalog = try await WidgetCatalogLoader.loadCatalog()
        // Ordena por data decrescente
        let sorted = catalog.sorted { $0.createdAt > $1.createdAt }
        return sorted.map { SignatureChoice(id: $0.uuid, createdAt: $0.createdAt) }
    }

    func allEntities() async throws -> [SignatureChoice] {
        try await suggestedEntities()
    }
}

// MARK: - DTOs e Loader no Widget (nomes exclusivos do widget)
struct WidgetSharedSignatureCatalogItem: Codable {
    let uuid: UUID
    let createdAt: Date
}

struct WidgetSharedSignatureData: Codable {
    let uuid: UUID
    let createdAt: Date
    let strokes: [WidgetSharedStroke]
}

struct WidgetSharedStroke: Codable, Hashable, Identifiable {
    var id: UUID
    var points: [WidgetSharedStrokePoint]
    var colorHex: String
    var lineWidth: CGFloat
}

struct WidgetSharedStrokePoint: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
}

enum WidgetCatalogLoader {
    static let appGroupID = "group.br.com.devbrains.SignatureWidgets"

    static func appGroupURL() -> URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("App Group URL not found for \(appGroupID).")
        }
        return url
    }

    static func catalogURL() -> URL {
        appGroupURL().appendingPathComponent("signatures_catalog.json", conformingTo: .json)
    }

    static func signatureFileURL(uuid: UUID) -> URL {
        appGroupURL().appendingPathComponent("signature_\(uuid.uuidString).json", conformingTo: .json)
    }

    static func loadCatalog() async throws -> [WidgetSharedSignatureCatalogItem] {
        let url = catalogURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([WidgetSharedSignatureCatalogItem].self, from: data)
    }

    static func loadSignature(uuid: UUID) async throws -> WidgetSharedSignatureData {
        let url = signatureFileURL(uuid: uuid)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WidgetSharedSignatureData.self, from: data)
    }
}

// MARK: - Intent de configuração do Widget

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Signature" }
    static var description: IntentDescription { "Choose which signature to show." }

    @Parameter(title: "Signature")
    var signature: SignatureChoice?
}
