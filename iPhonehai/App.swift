import SwiftUI

@main
struct iPhonehaiApp: App {
    init() {
        AgcConfigStore.shared.load()
    }

    var body: some Scene {
        WindowGroup {
            CameraRootView()
                .ignoresSafeArea()
        }
    }
}
