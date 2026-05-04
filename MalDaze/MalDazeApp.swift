import SwiftUI

@main
struct MalDazeApp: App {
    @NSApplicationDelegateAdaptor(MalDazeAppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            MenuBarDogLabel(mode: viewModel.petDisplayMode)
        }
        .menuBarExtraStyle(.window)

        Settings {
            MalDazeSettingsView()
        }
    }
}
