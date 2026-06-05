//
//  SignatureSharing.swift
//  SignatureWidget
//
//  Created by Ramon Santos on 16/11/25.
//

import Foundation
import SwiftUI
import WidgetKit
internal import UniformTypeIdentifiers

// MARK: - App Group

enum SignatureSharing {
    static let appGroupID = "group.br.com.devbrains.SignatureWidgets"

    static func appGroupURL() -> URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("App Group URL not found for \(appGroupID). Check Capabilities > App Groups for App and Widget targets.")
        }
        return url
    }

    static func catalogURL() -> URL {
        appGroupURL().appendingPathComponent("signatures_catalog.json", conformingTo: .json)
    }

    static func signatureFileURL(uuid: UUID) -> URL {
        appGroupURL().appendingPathComponent("signature_\(uuid.uuidString).json", conformingTo: .json)
    }
}

// MARK: - Shared DTOs (Codable)

struct SharedSignatureCatalogItem: Codable, Identifiable, Hashable {
    var id: UUID { uuid }
    let uuid: UUID
    let createdAt: Date
    let name: String

    init(uuid: UUID, createdAt: Date, name: String) {
        self.uuid = uuid; self.createdAt = createdAt; self.name = name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid      = try c.decode(UUID.self,   forKey: .uuid)
        createdAt = try c.decode(Date.self,   forKey: .createdAt)
        name      = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    }
}

struct SharedSignatureData: Codable {
    let uuid: UUID
    let createdAt: Date
    let name: String
    let strokes: [SharedStroke]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid      = try c.decode(UUID.self,          forKey: .uuid)
        createdAt = try c.decode(Date.self,          forKey: .createdAt)
        name      = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        strokes   = try c.decode([SharedStroke].self, forKey: .strokes)
    }
}

struct SharedStroke: Codable, Hashable, Identifiable {
    var id: UUID
    var points: [SharedStrokePoint]
    var colorHex: String
    var lineWidth: CGFloat
}

struct SharedStrokePoint: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
}

// MARK: - Converters (App models -> Shared DTOs)

extension SharedSignatureCatalogItem {
    init(from signature: Signature) {
        self.init(uuid: signature.uuid, createdAt: signature.createdAt, name: signature.name ?? "")
    }
}

extension SharedSignatureData {
    init(from signature: Signature) {
        self.uuid = signature.uuid
        self.createdAt = signature.createdAt
        self.name = signature.name ?? ""
        self.strokes = signature.strokes.map { SharedStroke(from: $0) }
    }
}

extension SharedStroke {
    init(from stroke: Stroke) {
        self.id = stroke.id
        self.points = stroke.points.map { SharedStrokePoint(x: $0.x, y: $0.y) }
        self.colorHex = stroke.colorHex
        self.lineWidth = stroke.lineWidth
    }
}

// MARK: - Write/Remove Catalog and Files (App side)

enum SignatureSharingWriter {
    static func writeSignature(_ signature: Signature) {
        let dataModel = SharedSignatureData(from: signature)
        let url = SignatureSharing.signatureFileURL(uuid: signature.uuid)
        do {
            let data = try JSONEncoder().encode(dataModel)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("SignatureSharingWriter.writeSignature error:", error)
        }
    }

    static func removeSignatureFile(uuid: UUID) {
        let url = SignatureSharing.signatureFileURL(uuid: uuid)
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            print("SignatureSharingWriter.removeSignatureFile error:", error)
        }
    }

    static func rebuildCatalog(from signatures: [Signature]) {
        let items = signatures.map { SharedSignatureCatalogItem(from: $0) }
        let url = SignatureSharing.catalogURL()
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("SignatureSharingWriter.rebuildCatalog error:", error)
        }
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
