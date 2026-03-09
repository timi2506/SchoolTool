import SwiftUI

extension Color {
    static var darkGray: Color {
#if os(iOS) || os(tvOS)
        return Color(uiColor: .darkGray)
        #elseif os(macOS)
        return Color(nsColor: .darkGray)
        #endif
    }
}

struct ColorSheet: View {
    @Binding var color: Color
    @Environment(\.dismiss) var dismiss
    var colors: [Color] = [
        .red,
        Color(hue: 0.03, saturation: 0.8, brightness: 1.0), // coral-ish
        .orange,
        .yellow,
        .mint,
        .green,
        .teal,
        .cyan,
        Color(hue: 0.6, saturation: 0.5, brightness: 1.0), // soft blue
        Color(hue: 0.58, saturation: 0.7, brightness: 0.9), // Bright blue-purple,
        .blue,
        .indigo,
        .purple,
        Color(hue: 0.9, saturation: 0.4, brightness: 1.0), // lavender-pink
        .pink,
        .brown,
        .darkGray,
        .gray,
    ]
    var body: some View {
        NavigationStack {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 52))
            ]) {
                ForEach(colors, id: \.self) { colorItem in
                    ColorButton(selection: $color, color: colorItem)
                }
            }
            .padding(.horizontal)
            .toolbar {
                #if os(iOS) || os(macOS)
                ToolbarItem(placement: .cancellationAction) {
                    ColorPicker("Custom Color", selection: $color, supportsOpacity: false)
                        .labelsHidden()
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        dismiss()
                    }, label: {
                        Group {
                            if #available(iOS 26, *) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .bold))
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 25))
                            }
                        }
                        .fontDesign(.rounded)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.gray)
                    })
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("Accent Color")
        }
    }
}

struct ColorButton: View {
    @Binding var selection: Color
    var color: Color
    
    var body: some View {
        Button(action: { selection = color }) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay {
                    Circle()
                        .stroke(color.opacity(0.25), lineWidth: 2)
                }
                .padding(5)
                .overlay {
                    if selection == color {
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct ColorSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var color: Color
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ColorSheet(color: $color)
                    .presentationDetents([.fraction(0.3)])
                    .presentationBackground {
                        ZStack {
                            #if os(iOS)
                            Color(uiColor: .secondarySystemBackground)
                            #elseif os(macOS)
                            Color(nsColor: .controlBackgroundColor)
                            #endif
                            LinearGradient(colors: [
                                color.opacity(0.05),
                                color.opacity(0.1),
                                color.opacity(0.15),
                                color.opacity(0.2),
                            ], startPoint: .top, endPoint: .bottom)
                        }
                    }
            }
    }
}

extension View {
    func colorSheet(isPresented: Binding<Bool>, color: Binding<Color>) -> some View {
        self.modifier(ColorSheetModifier(isPresented: isPresented, color: color))
    }
}

struct CustomColorPicker: View {
    init(isPresented: Binding<Bool>? = nil, color: Binding<Color>, label: @escaping () -> some View) {
        self.isPresented = isPresented
        self._color = color
        self.label = AnyView(label())
    }
    init(isPresented: Binding<Bool>? = nil, color: Binding<Color>, label: String) {
        self.isPresented = isPresented
        self._color = color
        self.label = AnyView(Text(label))
    }
    init(isPresented: Binding<Bool>? = nil, color: Binding<Color>) {
        self.isPresented = isPresented
        self._color = color
        self.label = AnyView(Text("Accent Color"))
    }
    var isPresented: Binding<Bool>?
    @State var internalIsPresented = false
    @Binding var color: Color
    var label: AnyView
    var body: some View {
        Button(action: {
            if isPresented != nil {
                isPresented?.wrappedValue.toggle()
            } else {
                internalIsPresented.toggle()
            }
        }) {
            HStack {
                label
                Spacer()
                Circle()
                    .frame(width: 25, height: 25)
                    .foregroundStyle(color)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .colorSheet(isPresented: isPresented ?? $internalIsPresented, color: $color)
    }
}
