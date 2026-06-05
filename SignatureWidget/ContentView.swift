//
//  ContentView.swift
//  SignatureWidget
//

import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: StoreManager
    @Query(sort: \Signature.createdAt, order: .reverse) private var signatures: [Signature]
    @State private var showingEditor     = false
    @State private var selectedSignature: Signature?
    @State private var showingPaywall    = false

    var body: some View {
        NavigationSplitView {
            Group {
                if signatures.isEmpty {
                    emptyState
                } else {
                    signatureList
                }
            }
            .navigationTitle("Signatures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LinearGradient.brand, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 240, ideal: 280)
#endif
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingEditor) { editorSheet }
            .sheet(isPresented: $showingPaywall) { PaywallView().environmentObject(store) }
            .safeAreaInset(edge: .top) { trialBanner }
        } detail: {
            detailPlaceholder
        }
        .onAppear {
            SignatureSharingWriter.rebuildCatalog(from: signatures)
        }
    }

    // MARK: - Trial Banner

    @ViewBuilder
    private var trialBanner: some View {
        if !store.isPurchased {
            Button { showingPaywall = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: TrialManager.isTrialActive ? "clock" : "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                    if TrialManager.isTrialActive {
                        Text("**\(TrialManager.trialDaysRemaining) days** left in trial — Subscribe to continue")
                            .font(.system(size: 13))
                    } else {
                        Text("Your trial ended — **Subscribe now** to keep the widget active")
                            .font(.system(size: 13))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(LinearGradient.brand)
            }
        }
    }

    // MARK: - List

    private var signatureList: some View {
        List {
            ForEach(signatures) { sig in
                NavigationLink {
                    SignatureDetailView(signature: sig,
                                       onEdit: { startEditing(signature: sig) })
                } label: {
                    SignatureRowView(signature: sig)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteSignatures)
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient.brandSubtle)
                    .frame(width: 136, height: 136)
                AppLogoMarkView()
                    .frame(width: 80, height: 80)
            }

            VStack(spacing: 8) {
                Text("No signatures")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Create your first signature\nand add it to the widget.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                selectedSignature = Signature()
                showingEditor = true
            } label: {
                Label("New Signature", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(LinearGradient.brand)
                    .clipShape(Capsule())
                    .brandShadow()
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
#if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            EditButton().tint(.brandIndigo)
        }
#endif
        ToolbarItem(placement: .primaryAction) {
            Button {
                selectedSignature = Signature()
                showingEditor = true
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient.brand)
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Editor Sheet

    @ViewBuilder
    private var editorSheet: some View {
        if let sig = selectedSignature {
            SignatureEditorView(signature: sig) { result in
                switch result {
                case .saved:
                    if !isExistingSignature(sig) {
                        withAnimation { modelContext.insert(sig) }
                        SignatureSharingWriter.rebuildCatalog(from: signaturesAfterInsert(sig))
                    } else {
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

    // MARK: - Detail Placeholder

    private var detailPlaceholder: some View {
        VStack(spacing: 14) {
            AppLogoMarkView()
                .frame(width: 72, height: 72)
                .opacity(0.35)
            Text("Select or create a signature")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

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
            removedUUIDs.forEach { SignatureSharingWriter.removeSignatureFile(uuid: $0) }
            SignatureSharingWriter.rebuildCatalog(from: signatures)
            SignatureSharingWriter.reloadWidgets()
        }
    }
}

// MARK: - Signature Row

private struct SignatureRowView: View {
    let signature: Signature

    var body: some View {
        HStack(spacing: 14) {
            SignatureCanvasReadonly(signature: signature)
                .frame(width: 80, height: 52)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.brandIndigo.opacity(0.14), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(signature.name?.isEmpty == false ? signature.name! : String(localized: "Signature"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(signature.createdAt, format: Date.FormatStyle(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .cardSurface(cornerRadius: 14)
    }
}

// MARK: - Signature Detail

struct SignatureDetailView: View {
    let signature: Signature
    var onEdit: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Preview
                SignatureCanvasReadonly(signature: signature)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.brandIndigo.opacity(0.12), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
                    .padding(.horizontal)

                // Date info
                HStack {
                    Label(
                        signature.createdAt.formatted(date: .long, time: .shortened),
                        systemImage: "calendar"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                // Edit button
                Button(action: onEdit) {
                    Label("Edit Signature", systemImage: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(LinearGradient.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .brandShadow()
                }
                .padding(.horizontal)
            }
            .padding(.top, 28)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(signature.name?.isEmpty == false ? signature.name! : String(localized: "Signature"))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

// MARK: - Read-only Canvas (shared between list & detail)

struct SignatureCanvasReadonly: View {
    let signature: Signature

    var body: some View {
        Canvas { context, size in
            for stroke in signature.strokes {
                var path = Path()
                let pts = stroke.points.map {
                    CGPoint(x: $0.x * size.width, y: $0.y * size.height)
                }
                guard let first = pts.first else { continue }
                path.move(to: first)
                for p in pts.dropFirst() { path.addLine(to: p) }
                context.stroke(path, with: .color(stroke.color), lineWidth: stroke.lineWidth)
            }
        }
        .aspectRatio(3, contentMode: .fit)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Signature.self, inMemory: true)
}
