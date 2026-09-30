//
//  FitnessTrackerIOSApp.swift
//  FitnessTrackerIOS
//
//  Created by Hai Do on 30/9/26.
//

import SwiftUI
import SwiftData
import FitnessTracker

@main
@MainActor
struct FitnessTrackerApp: App {
    @State private var container: ModelContainer?
    @State private var startupError: String?
    @State private var selection = ProfileContext()

    private func loadStore() {
        do {
            let loaded = try ModelContainerFactory.make()
            try SeedData.install(in: loaded.mainContext)
            container = loaded
            startupError = nil
        } catch {
            startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootTabView().environment(selection).modelContainer(container)
                } else if let startupError {
                    ContentUnavailableView {
                        Label("Couldn’t open fitness data", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(startupError)
                    } actions: {
                        Button("Try again", action: loadStore).buttonStyle(.borderedProminent)
                    }
                } else { ProgressView("Opening fitness data") }
            }.task { if container == nil && startupError == nil { loadStore() } }
        }
    }
}
