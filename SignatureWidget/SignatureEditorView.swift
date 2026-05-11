//
//  SignatureEditorView.swift
//  SignatureWidget
//
//  Created by Ramon Santos on 16/11/25.
//

import SwiftUI

struct SignatureEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentStroke = Stroke()
    @State private var workingStrokes: [Stroke] = []
    @State private var color: Color
    @State private var lineWidth: CGFloat

    let signature: Signature
    let onFinish: (Result) -> Void

    enum Result {
        case saved
        case cancelled
    }

    init(signature: Signature, onFinish: @escaping (Result) -> Void) {
        self.signature = signature
        self.onFinish = onFinish
        _color = State(initialValue: Color.fromHexRGBA(signature.strokeColorHex) ?? .primary)
        _lineWidth = State(initialValue: signature.strokeWidth)
        _workingStrokes = State(initialValue: signature.strokes)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                    // Área de desenho
                    GeometryReader { geo in
                        Canvas { context, size in
                            // Strokes já desenhados
                            for stroke in workingStrokes {
                                draw(stroke: stroke, in: &context, size: size)
                            }
                            // Stroke atual enquanto desenha
                            draw(stroke: currentStroke, in: &context, size: size)
                        }
                        .gesture(drawingGesture(in: geo.size))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .aspectRatio(3, contentMode: .fit)
                .padding(.horizontal)

                // Controles
                HStack {
                    ColorPicker("Cor", selection: $color)
                        .labelsHidden()
                    Slider(value: $lineWidth, in: 1...16) {
                        Text("Espessura")
                    } minimumValueLabel: {
                        Text("1")
                            .font(.caption)
                    } maximumValueLabel: {
                        Text("16")
                            .font(.caption)
                    }
                    .frame(maxWidth: 200)
                    Spacer()
                    Button {
                        if !workingStrokes.isEmpty {
                            _ = workingStrokes.popLast()
                        }
                    } label: {
                        Label("Desfazer", systemImage: "arrow.uturn.left")
                    }
                    Button {
                        workingStrokes.removeAll()
                        currentStroke = Stroke()
                    } label: {
                        Label("Limpar", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Nova Assinatura")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onFinish(.cancelled)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        // Salva no modelo
                        signature.strokeColorHex = color.toHexRGBA()
                        signature.strokeWidth = lineWidth
                        signature.strokes = workingStrokes

                        // Exporta para o App Group e recarrega widgets
                        SignatureSharingWriter.writeSignature(signature)
                        // O catálogo será reconstruído pelo chamador (ContentView) quando inserir no banco
                        SignatureSharingWriter.reloadWidgets()

                        onFinish(.saved)
                        dismiss()
                    }
                    .disabled(workingStrokes.isEmpty && currentStroke.points.isEmpty)
                }
            }
        }
    }

    // MARK: - Drawing

    private func draw(stroke: Stroke, in context: inout GraphicsContext, size: CGSize) {
        guard !stroke.points.isEmpty else { return }
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

    private func drawingGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0.1, coordinateSpace: .local)
            .onChanged { value in
                // se começamos um novo stroke
                if currentStroke.points.isEmpty {
                    currentStroke = Stroke(points: [], color: color, lineWidth: lineWidth)
                }
                let point = value.location
                let norm = StrokePoint(point.x / size.width, point.y / size.height)
                currentStroke.points.append(norm)
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
    let signature = Signature()
    SignatureEditorView(signature: signature) { _ in }
}

