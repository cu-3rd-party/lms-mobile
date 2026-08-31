import SwiftUI

struct NativeTabItem: Identifiable {
    let id: Int
    let icon: String
    let selectedIcon: String
    let label: String
}

@available(iOS 16.0, *)
final class NativeTabBarModel: ObservableObject {
    @Published var items: [NativeTabItem]
    @Published var selected: Int
    @Published var palette: AppPalette

    init(items: [NativeTabItem], selected: Int, palette: AppPalette) {
        self.items = items
        self.selected = selected
        self.palette = palette
    }
}

@available(iOS 16.0, *)
private struct BarBackground: ViewModifier {
    let palette: AppPalette

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(palette.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(palette.border, lineWidth: 1))
                .shadow(color: palette.shadow, radius: 12, x: 0, y: 4)
        }
    }
}

@available(iOS 16.0, *)
struct NativeTabBarHost: View {
    static let barHeight: CGFloat = 58
    static let bottomInset: CGFloat = 8
    static let horizontalInset: CGFloat = 16

    @ObservedObject var model: NativeTabBarModel
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            bar
                .padding(.horizontal, Self.horizontalInset)
                .padding(.bottom, Self.bottomInset)
        }
        .environment(\.colorScheme, model.palette.colorScheme)
    }

    @ViewBuilder
    private var bar: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                itemsRow.modifier(BarBackground(palette: model.palette))
            }
        } else {
            itemsRow.modifier(BarBackground(palette: model.palette))
        }
    }

    private var itemsRow: some View {
        HStack(spacing: 0) {
            ForEach(model.items) { item in
                Button {
                    onSelect(item.id)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.id == model.selected ? item.selectedIcon : item.icon)
                            .font(.system(size: 21, weight: .regular))
                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(item.id == model.selected ? model.palette.accent : model.palette.textTertiary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 6)
        .frame(height: Self.barHeight)
    }
}

final class PassthroughContainerView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}
