import SwiftData
import SwiftUI

enum MeetingFilter: Hashable {
    case all, starred

    var title: String { self == .all ? "Meetings" : "Starred" }
}

/// The meetings list with a slide-out drawer on the left.
struct RootView: View {
    @AppStorage(AppSettings.appearance) private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(AppSettings.accent) private var accentRaw = AccentChoice.maroon.rawValue

    @State private var filter: MeetingFilter = .all
    @State private var path: [Meeting] = []
    @State private var isSearching = false
    @State private var isDrawerOpen = false
    @State private var showingSettings = false
    // Plain state, not @GestureState: that resets to zero the instant a drag ends, before the open/close
    // animation starts, which made the drawer jump back and then slide.
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let drawerWidth: CGFloat = 290
    private let cornerRadius: CGFloat = 32

    /// 0 when closed, 1 when open, in between while dragging.
    private var progress: CGFloat {
        let base: CGFloat = isDrawerOpen ? drawerWidth : 0
        return min(max((base + dragOffset) / drawerWidth, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            HomeView(filter: filter, path: $path, isSearching: $isSearching, openDrawer: { setDrawer(open: true) })
                // A new accent only reaches views that redraw; rebuild the list when it changes.
                .id(accentRaw)
                // Slide the list with the drawer as a pure render transform, so the navigation bar
                // doesn't re-lay out its large title on every frame.
                .visualEffect { [shift = progress * drawerWidth] content, _ in
                    content.offset(x: shift)
                }
                .overlay {
                    Color.black
                        .opacity(0.35 * progress)
                        .ignoresSafeArea()
                        .allowsHitTesting(isDrawerOpen)
                        .onTapGesture { setDrawer(open: false) }
                }

            DrawerView(
                filter: filter,
                select: { filter in
                    showList(filter)
                    setDrawer(open: false)
                },
                search: {
                    showList(.all)
                    setDrawer(open: false)
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        isSearching = true
                    }
                },
                openSettings: {
                    setDrawer(open: false)
                    showingSettings = true
                }
            )
            .frame(width: drawerWidth)
            .background {
                UnevenRoundedRectangle(bottomTrailingRadius: cornerRadius, topTrailingRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.3 * progress), radius: 24, x: 6)
                    .ignoresSafeArea()
            }
            .offset(x: (progress - 1) * (drawerWidth + 30))

            // Swipe in from the left edge, only on the list itself (the detail screen uses that edge for back).
            // Kept narrow so it doesn't swallow taps and swipes on the rows.
            if !isDrawerOpen && path.isEmpty {
                Color.clear
                    .frame(width: 14)
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .gesture(drawerDrag)
            }
        }
        .gesture(drawerDrag, isEnabled: isDrawerOpen)
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .task {
            if DemoData.cyclesDrawer {
                for filter in [MeetingFilter.starred, .all, .starred, .all] {
                    try? await Task.sleep(for: .milliseconds(900))
                    setDrawer(open: true)
                    try? await Task.sleep(for: .milliseconds(900))
                    showList(filter)
                    setDrawer(open: false)
                }
            }
            if DemoData.opensDrawer { setDrawer(open: true) }
            if DemoData.opensSettings { showingSettings = true }
        }
        .preferredColorScheme(Appearance(rawValue: appearanceRaw)?.colorScheme)
        .tint(AccentChoice(rawValue: accentRaw)?.color ?? Theme.accent)
    }

    private var drawerDrag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                // Only follow mostly sideways drags, so scrolling the list never nudges the drawer.
                guard isDragging || abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                isDragging = true
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                let predicted = (isDrawerOpen ? drawerWidth : 0) + value.predictedEndTranslation.width
                setDrawer(open: predicted > drawerWidth / 2)
            }
    }

    /// Swaps the list without animation, so the title changes in one step under the closing drawer
    /// instead of cross-fading alongside it.
    private func showList(_ filter: MeetingFilter) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.filter = filter
            path = []
        }
    }

    private func setDrawer(open: Bool) {
        withAnimation(.snappy(duration: 0.32)) {
            isDrawerOpen = open
            dragOffset = 0
        }
    }
}

private struct DrawerView: View {
    @Query private var meetings: [Meeting]
    let filter: MeetingFilter
    let select: (MeetingFilter) -> Void
    let search: () -> Void
    let openSettings: () -> Void

    private var starredCount: Int { meetings.filter(\.isStarred).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Bucephalus")
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 28)

            VStack(spacing: 4) {
                DrawerRow(title: "All meetings", icon: "tray.full", count: meetings.count,
                          isSelected: filter == .all) { select(.all) }
                DrawerRow(title: "Starred", icon: "star", count: starredCount,
                          isSelected: filter == .starred) { select(.starred) }
                DrawerRow(title: "Search", icon: "magnifyingglass", action: search)
            }
            .padding(.horizontal, 10)

            Spacer()

            Divider().padding(.horizontal, 20)
            DrawerRow(title: "Settings", icon: "gearshape", action: openSettings)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct DrawerRow: View {
    let title: String
    let icon: String
    var count: Int?
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(.system(size: 17))
                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                    .frame(width: 24)
                Text(title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                Spacer()
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(isSelected ? Color(.tertiarySystemFill) : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
