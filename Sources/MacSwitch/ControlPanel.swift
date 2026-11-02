import SwiftUI
import MacSwitchCore

struct ControlPanel: View {
    let model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            header
            HStack(alignment: .top, spacing: 8) {
                ControlButton(icon: "moon", title: "잠자기 허용", selected: model.sleepMode == .allowed,
                              tooltip: "잠자기를 허용합니다. 즉시 잠들지는 않습니다.",
                              action: { model.chooseSleep(.allowed) })
                    .disabled(model.isChangingSleep)
                ControlButton(icon: "sun", title: "깨어 있기", selected: model.sleepMode == .prevented,
                              tooltip: "잠자기를 금지합니다. pmset disablesleep 1을 적용합니다.",
                              action: { model.chooseSleep(.prevented) })
                    .disabled(model.isChangingSleep)

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary.opacity(0.09))
                    .frame(width: 1, height: 38)
                    .padding(.horizontal, 3)
                    .padding(.top, 10)
                    .accessibilityHidden(true)

                ControlButton(icon: "lock", title: "잠그기", selected: model.isKeyboardLocked,
                              tooltip: "키보드 입력을 차단합니다. 마우스와 트랙패드는 사용할 수 있습니다. 비상 해제: Esc를 빠르게 세 번",
                              action: model.lockKeyboard)
                    .disabled(model.isChangingSleep)
                ControlButton(icon: "lock-open", title: "열기", selected: !model.isKeyboardLocked,
                              tooltip: "키보드 잠금을 해제하고 다시 입력할 수 있게 합니다.",
                              action: model.unlockKeyboard)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(model.isKeyboardLocked ? Color.orange : Color.accentColor)
                        .frame(width: 5, height: 5)
                    if model.isChangingSleep {
                        Text(PasswordMessages().prompt)
                    } else {
                        Text(model.summary)
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

                if model.isKeyboardLocked {
                    Text("비상 해제  Esc를 빠르게 세 번")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                if let notice = model.notice {
                    Text(notice)
                        .font(.system(size: 11))
                        .foregroundStyle(model.noticeIsError ? Color.orange : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("notice")
                }

                if model.needsPermission || !model.hasPermission {
                    Button(action: model.openPermissionSettings) {
                        HStack(spacing: 4) {
                            Text("키보드 잠금 권한 설정")
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .help("시스템 설정에서 MacSwitch의 접근성 권한을 허용합니다.")
                }
            }
        }
        .padding(19)
        .frame(width: 350, alignment: .leading)
        .background(colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color.white.opacity(0.94))
        .tint(Color(red: 0.24, green: 0.39, blue: 0.95))
    }

    private var header: some View {
        HStack(spacing: 7) {
            ReiconView(name: "laptop", size: 16)
                .foregroundStyle(.primary.opacity(0.8))
            Text("MacSwitch")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Menu {
                Button("상태 다시 확인", action: model.refresh)
                    .disabled(model.isChangingSleep)
                Button("키보드 잠금 권한 설정…", action: model.openPermissionSettings)
                Divider()
                Text("비상 해제: Esc를 빠르게 세 번")
                Button("아이콘: Reicon") {
                    NSWorkspace.shared.open(URL(string: "https://reicon.dev/icons")!)
                }
                Divider()
                Button("MacSwitch 종료") {
                    model.stop()
                    NSApp.terminate(nil)
                }
                .disabled(model.isChangingSleep)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 22, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("상태 확인, 권한 설정 및 종료")
            .accessibilityLabel("추가 메뉴")
        }
    }
}

private struct ControlButton: View {
    let icon: String
    let title: String
    let selected: Bool
    let tooltip: String
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(background)
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.045), lineWidth: 1)
                        }
                    ReiconView(name: icon, filled: selected)
                        .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.57))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if selected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 4)
                            .padding(8)
                    }
                }
                .frame(width: 66, height: 58)
                Text(title)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering = $0 }
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "활성" : "비활성")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(icon)
    }

    private var background: Color {
        if selected { return Color.accentColor.opacity(hovering ? 0.16 : 0.1) }
        return Color.primary.opacity(hovering ? 0.065 : 0.025)
    }
}
