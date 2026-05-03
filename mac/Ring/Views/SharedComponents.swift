import SwiftUI

// MARK: - Clip Text Field

struct ClipTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(
                            isFocused ? Color.borderFocus : Color.borderDefault,
                            lineWidth: 1
                        )
                )

            Group {
                if isSecure {
                    SecureField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundColor(.textTertiary)
                    )
                } else {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundColor(.textTertiary)
                    )
                }
            }
            .font(.ringBody)
            .foregroundColor(.textPrimary)
            .textFieldStyle(.plain)
            .padding(.horizontal, Spacing.sm)
            .focused($isFocused)
        }
        .frame(height: Layout.inputHeight)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isFocused)
    }
}

// MARK: - Primary Button

struct ClipPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(
                        isDisabled ? Color.accent.opacity(0.35) :
                        isHovered  ? Color.accentDeep : Color.accent
                    )
                    .frame(height: Layout.buttonHeight)

                if isLoading {
                    ProgressView().scaleEffect(0.65).tint(.white)
                } else {
                    Text(title)
                        .font(.ringBodyMedium)
                        .foregroundColor(.white.opacity(isDisabled ? 0.45 : 1))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .onHover { isHovered = !isDisabled && $0 }
        .animation(.spring(response: 0.20, dampingFraction: 0.80), value: isHovered)
    }
}

// MARK: - Segmented Picker

struct SegmentedPicker: View {
    let options: [String]
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(Array(options.enumerated()), id: \.offset) { idx, label in
                Button(label) { onSelect(idx) }
                    .font(idx == selected ? .ringCaptionMed : .ringCaption)
                    .foregroundColor(idx == selected ? .textPrimary : .textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        idx == selected ?
                        RoundedRectangle(cornerRadius: Layout.segmentCornerRadius)
                            .fill(Color.segmentSelected) : nil
                    )
                    .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(Color.borderSubtle, lineWidth: 0.5)
                )
        )
        .animation(.spring(response: 0.20, dampingFraction: 0.82), value: selected)
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(configuration.isPressed ? Color.activeFill : Color.clear)
            )
            .animation(.spring(response: 0.18, dampingFraction: 0.80), value: configuration.isPressed)
    }
}

// MARK: - Hairline Divider

struct HairlineDivider: View {
    var leadingPad: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: 0.5)
            .padding(.leading, leadingPad)
    }
}
