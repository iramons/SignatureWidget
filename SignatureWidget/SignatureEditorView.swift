//
//  SignatureEditorView.swift
//  SignatureWidget
//

import SwiftUI

struct SignatureEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentStroke  = Stroke()
    @State private var workingStrokes: [Stroke] = []
    @State private var color: Color
    @State private var lineWidth: CGFloat

    let signature: Signature
    let onFinish: (Result) -> Void

    enum Result { case saved, cancelled }

    init(signature: Signature, onFinish: @escaping (Result) -> Void) {
        self.signature = signature
        self.onFinish  = onFinish
        _color          = State(initialValue: Color.fromHexRGBA(signature.strokeColorHex) ?? .primary)
        _lineWidth      = State(initialValue: signature.strokeWidth)
        _workingStrokes = State(initialValue: signature.strokes)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Drawing canvas ──
                canvasArea
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // ── Controls strip ──
                controlsStrip
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                // ── Save button ──
                saveButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Nova Assinatura")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onFinish(.cancelled)
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Canvas

    private var canvasArea: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.brandIndigo.opacity(0.25), Color.brandPurple.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)

            // Subtle guide text when blank
            if workingStrokes.isEmpty && currentStroke.points.isEmpty {
                Text("Desenhe aqui")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.brandIndigo.opacity(0.25))
                    .allowsHitTesting(false)
            }

            // Drawing canvas
            GeometryReader { geo in
                Canvas { ctx, size in
                    for stroke in workingStrokes {
                        draw(stroke: stroke, in: &ctx, size: size)
                    }
                    draw(stroke: currentStroke, in: &ctx, size: size)
                }
                .gesture(drawingGesture(in: geo.size))
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .aspectRatio(3, contentMode: .fit)
    }

    // MARK: - Controls Strip

    private var controlsStrip: some View {
        HStack(spacing: 12) {
            // Color picker
            ColorPicker("", selection: $color)
                .labelsHidden()
                .frame(width: 36, height: 36)

            // Line-width preview dot + slider
            Circle()
                .fill(color)
                .frame(width: lineWidth * 1.5, height: lineWidth * 1.5)
                .frame(width: 22, height: 22)
                .animation(.easeOut(duration: 0.15), value: lineWidth)

            Slider(value: $lineWidth, in: 1...16)
                .tint(.brandIndigo)
                .frame(maxWidth: .infinity)

            Divider().frame(height: 24)

            // Undo
            Button {
                if !workingStrokes.isEmpty { workingStrokes.removeLast() }
            } label: {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(workingStrokes.isEmpty ? Color.secondary : Color.brandIndigo)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .disabled(workingStrokes.isEmpty)

            // Clear
            Button {
                workingStrokes.removeAll()
                currentStroke = Stroke()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(workingStrokes.isEmpty ? Color.secondary : Color.red)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .disabled(workingStrokes.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - Save Button

    private var saveButton: some View {
        let isEmpty = workingStrokes.isEmpty && currentStroke.points.isEmpty
        return Button {
            signature.strokeColorHex = color.toHexRGBA()
            signature.strokeWidth    = lineWidth
            signature.strokes        = workingStrokes
            SignatureSharingWriter.writeSignature(signature)
            SignatureSharingWriter.reloadWidgets()
            onFinish(.saved)
            dismiss()
        } label: {
            Label("Salvar Assinatura", systemImage: "checkmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if isEmpty {
                            LinearGradient(colors: [Color.secondary.opacity(0.4), Color.secondary.opacity(0.3)],
                                           startPoint: .leading, endPoint: .trailing)
                        } else {
                            LinearGradient.brand
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .brandShadow(radius: isEmpty ? 0 : 14, y: isEmpty ? 0 : 6)
        }
        .disabled(isEmpty)
        .animation(.easeOut(duration: 0.2), value: isEmpty)
    }

    // MARK: - Drawing Helpers

    private func draw(stroke: Stroke, in context: inout GraphicsContext, size: CGSize) {
        guard !stroke.points.isEmpty else { return }
        var path = Path()
        let pts = stroke.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        if let first = pts.first {
            path.move(to: first)
            for p in pts.dropFirst() { path.addLine(to: p) }
        }
        context.stroke(path, with: .color(stroke.color),
                       style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))
    }

    private func drawingGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0.1, coordinateSpace: .local)
            .onChanged { value in
                if currentStroke.points.isEmpty {
                    currentStroke = Stroke(points: [], color: color, lineWidth: lineWidth)
                }
                let p = value.location
                currentStroke.points.append(StrokePoint(p.x / size.width, p.y / size.height))
            }
            .onEnded { _ in
                if !currentStroke.points.isEmpty {
                    workingStrokes.append(currentStroke)
                }
                currentStroke = Stroke()
            }
    }
}

#Preview {
    SignatureEditorView(signature: Signature()) { _ in }
}
