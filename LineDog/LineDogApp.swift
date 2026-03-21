import SwiftUI

@main
struct LineDogApp: App {
    @NSApplicationDelegateAdaptor(LineDogAppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            MenuBarDogLabel(mode: viewModel.petDisplayMode)
        }
        .menuBarExtraStyle(.window)

        Settings {
            LineDogSettingsView()
        }
    }
}
