import AppIntents
import SwiftData
import SwiftUI

@main
struct CoffeeTasterApp: App {
    init() {
        CoffeeShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AppRouter.shared)
        }
        .modelContainer(DataStore.container)
    }
}

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.didOnboard) private var didOnboard = false
    @State private var showWelcome = false

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            LogView()
                .tabItem { Label("Log", systemImage: "square.and.pencil") }
                .tag(AppTab.log)
            TimerView()
                .tabItem { Label("Timer", systemImage: "timer") }
                .tag(AppTab.timer)
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet") }
                .tag(AppTab.history)
            BeansView()
                .tabItem { Label("Beans", systemImage: "leaf") }
                .tag(AppTab.beans)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .onAppear {
            if !didOnboard {
                showWelcome = true
                didOnboard = true
            }
            // Makes sure the local CSV copy exists (and catches up the sync folder).
            FolderSync.shared.export(context: context)
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeView()
        }
    }
}
