import SwiftUI

// MARK: - Clip Text Field

struct ClipTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
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
                        prompt: Text(placeholder).foregroundColor(.textPlaceholder)
                    )
                } else {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundColor(.textPlaceholder)
                    )
                }
            }
            .font(.cliprBody)
            .foregroundColor(.textPrimary)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .focused($isFocused)
        }
        .frame(height: 36)
        .animation(.easeInOut(duration: Duration.micro), value: isFocused)
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isDisabled ? Color.accent.opacity(0.35) :
                        isHovered  ? Color.accentDeep : Color.accent
                    )
                    .frame(height: 36)

                if isLoading {
                    ProgressView().scaleEffect(0.65).tint(.white)
                } else {
                    Text(title)
                        .font(.cliprBodyMedium)
                        .foregroundColor(.white.opacity(isDisabled ? 0.5 : 1))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .onHover { isHovered = !isDisabled && $0 }
        .animation(.easeInOut(duration: Duration.instant), value: isHovered)
    }
}

// MARK: - Segmented Picker

struct SegmentedPicker: View {
    let options: [String]
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { idx, label in
                Button(label) { onSelect(idx) }
                    .font(idx == selected ? .cliprCaptionMed : .cliprCaption)
                    .foregroundColor(idx == selected ? .textPrimary : .textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .background(
                        idx == selected ?
                        RoundedRectangle(cornerRadius: Layout.segmentCornerRadius)
                            .fill(Color.segmentSelected) : nil
                    )
                    .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Layout.segmentCornerRadius + 2)
                .fill(Color.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.segmentCornerRadius + 2)
                        .strokeBorder(Color.borderSubtle, lineWidth: 0.5)
                )
        )
        .animation(.easeInOut(duration: Duration.instant), value: selected)
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.activeFill : Color.clear)
            )
            .animation(.easeInOut(duration: Duration.micro), value: configuration.isPressed)
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
