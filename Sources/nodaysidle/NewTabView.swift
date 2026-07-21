import SwiftUI

struct NewTabView: View {
    @Bindable var store: BrowserStore
    let tabID: UUID
    @FocusState private var focused: Bool
    @State private var query = ""

    var body: some View {
        ZStack {
            Nodaysidle.ColorToken.void

            HStack(spacing: 10) {
                NodaysidleIcon(name: Nodaysidle.Symbol.search, size: 14)
                    .foregroundStyle(Nodaysidle.ColorToken.quiet)
                    .accessibilityHidden(true)

                TextField(
                    "",
                    text: $query,
                    prompt: Text(Nodaysidle.Copy.searchPlaceholder)
                        .foregroundStyle(Nodaysidle.ColorToken.muted)
                )
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(Nodaysidle.ColorToken.text)
                    .focused($focused)
                    .onSubmit { submit() }
                    .onKeyPress(.escape) {
                        query = ""
                        return .handled
                    }
                    .accessibilityLabel(Nodaysidle.Copy.searchPlaceholder)

                Text("↵")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Nodaysidle.ColorToken.quiet)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Nodaysidle.ColorToken.surface)
                    .clipShape(Capsule())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 520)
            .frame(height: 44)
            .background(Nodaysidle.ColorToken.surface)
            .overlay(
                Capsule()
                    .stroke(focused ? Nodaysidle.ColorToken.accent : Nodaysidle.ColorToken.lineStrong, lineWidth: 1)
            )
            .clipShape(Capsule())
            .frame(maxHeight: .infinity)
        }
        .task(id: store.pendingNewTabFocusID) {
            await Task.yield()
            focusIfPending()
        }
        .onChange(of: store.selectedTabID) { _, selectedID in
            if selectedID != tabID {
                focused = false
            }
        }
    }

    private func focusIfPending() {
        guard store.selectedTabID == tabID,
              store.pendingNewTabFocusID == tabID
        else {
            if store.selectedTabID != tabID { focused = false }
            return
        }
        focused = true
        store.pendingNewTabFocusID = nil
    }

    private func submit() {
        guard store.selectedTabID == tabID else { return }
        store.navigateSelected(to: query)
        query = ""
    }
}
