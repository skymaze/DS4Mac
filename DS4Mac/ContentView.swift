//
//  ContentView.swift
//  DS4Mac
//
//  Created by 蒋阅 on 2026/5/16.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        SettingsView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
