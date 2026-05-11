//
//  ContentView.swift
//  SignatureWidget
//
//  Created by Ramon Santos on 16/11/25.
//

import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Signature.createdAt, order: .reverse) private var signatures: [Signature]
    @State private var showingEditor = false
    @State private var selectedSignature: Signature?

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(signatures) { sig in
                    NavigationLink {
                        SignatureDetailView(signature: sig,
                                            onEdit: { startEditing(signature: sig) })
                    } label: {
                        HStack {
                            SignatureThumbnail(signature: sig)
                                .frame(width: 56, height: 56)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading) {
                                Text("Assinatura")
                                    .font(.headline)
                                Text(sig.createdAt, format: Date.FormatStyle(date: .numeric, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteSignatures)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button {
                        // Nova assinatura
                        selectedSignature = Signature()
                        showingEditor = true
                    } label: {
                        Label("Nova Assinatura", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                if let sig = selectedSignature {
                    SignatureEditorView(signature: sig) { result in
                        switch result {
                        case .saved:
                            if !isExistingSignature(sig) {
                                // Inserção de novo item
                                withAnimation {
                                    modelContext.insert(sig)
                                }
                                // Export individual (já feito no editor) e reconstrói catálogo
                                SignatureSharingWriter.rebuildCatalog(from: signaturesAfterInsert(sig))
                            } else {
                                // Edição de item existente: só reexporta e reconstrói catálogo
                                SignatureSharingWriter.writeSignature(sig)
                                SignatureSharingWriter.rebuildCatalog(from: signatures)
                            }
                            SignatureSharingWriter.reloadWidgets()
                        case .cancelled:
                            break
                        }
                        showingEditor = false
                    }
                }
            }
        } detail: {
            Text("Selecione ou crie uma assinatura")
                .foregroundStyle(.secondary)
        }
        .onAppear {
            // Garante que o catálogo exista ao abrir o app
            SignatureSharingWriter.rebuildCatalog(from: signatures)
        }
    }

    // MARK: - Helpers de edição

    private func startEditing(signature: Signature) {
        selectedSignature = signature
        showingEditor = true
    }

    private func isExistingSignature(_ sig: Signature) -> Bool {
        signatures.contains(where: { $0.uuid == sig.uuid })
    }

    private func signaturesAfterInsert(_ inserted: Signature) -> [Signature] {
        var array = signatures
        if !array.contains(where: { $0.uuid == inserted.uuid }) {
            array.insert(inserted, at: 0)
        }
        return array
    }

    private func deleteSignatures(offsets: IndexSet) {
        withAnimation {
            var removedUUIDs: [UUID] = []
            for index in offsets {
                let sig = signatures[index]
                removedUUIDs.append(sig.uuid)
                modelContext.delete(sig)
            }
            // Remove arquivos individuais e reconstrói catálogo
            removedUUIDs.forEach { SignatureSharingWriter.removeSignatureFile(uuid: $0) }
            SignatureSharingWriter.rebuildCatalog(from: signatures)
            SignatureSharingWriter.reloadWidgets()
        }
    }
}

// MARK: - Small helpers

private struct SignatureDetailView: View {
    let signature: Signature
    var onEdit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            SignatureCanvasReadonly(signature: signature)
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()
            Text(signature.createdAt, style: .date)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button {
                    onEdit()
                } label: {
                    Label("Editar", systemImage: "pencil")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Assinatura")
    }
}

private struct SignatureThumbnail: View {
    let signature: Signature
    var body: some View {
        SignatureCanvasReadonly(signature: signature)
            .contentShape(Rectangle())
    }
}

private struct SignatureCanvasReadonly: View {
    let signature: Signature
    var body: some View {
        Canvas { context, size in
            for stroke in signature.strokes {
                var path = Path()
                let pts = stroke.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                if let first = pts.first {
                    path.move(to: first)
                    for p in pts.dropFirst() {
                        path.addLine(to: p)
                    }
                }
                context.stroke(path,
                               with: .color(stroke.color),
                               lineWidth: stroke.lineWidth)
            }
        }
        .aspectRatio(3, contentMode: .fit)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Signature.self, inMemory: true)
}
