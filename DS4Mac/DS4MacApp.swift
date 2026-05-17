//
//  DS4MacApp.swift
//  DS4Mac
//
//  Created by 蒋阅 on 2026/5/16.
//

import SwiftUI

@main
struct DS4MacApp: App {
    @StateObject private var appModel = AppModel()

    init() {
        AppPreferences.applyLanguage()
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView()
                .environmentObject(appModel)
        } label: {
            Image(systemName: appModel.status.systemImage)
            Text("DS4")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .onAppear {
                    AppWindowPresenter.bringVisibleWindowsForward()
                }
        }
    }
}
