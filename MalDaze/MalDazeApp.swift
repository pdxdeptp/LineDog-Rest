import SwiftUI

@main
struct MalDazeApp: App {
    @NSApplicationDelegateAdaptor(MalDazeAppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    init() {
        MalDazeDefaults.migrateIdlePetAnimationIntensityFromLegacyIfNeeded()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarSettingsMenuView()
        } label: {
            MenuBarDogLabel(mode: viewModel.petDisplayMode)
        }
        .menuBarExtraStyle(.window)

        Settings {
            MalDazeSettingsView()
        }
    }
}

private struct MenuBarSettingsMenuView: View {
    var body: some View {
        Button(action: {
            MalDazeSettingsWindowPresenter.present()
        }) {
            Label("设置…", systemImage: "gearshape")
        }
    }
}
