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
            MenuBarContentView(viewModel: viewModel)
                .interactiveDismissDisabled(true)
        } label: {
            MenuBarDogLabel(mode: viewModel.petDisplayMode)
        }
        .menuBarExtraStyle(.window)

        Settings {
            MalDazeSettingsView()
        }
    }
}
