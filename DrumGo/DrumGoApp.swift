//
//  DrumGoApp.swift
//  DrumGo
//
//  Created by 李棋 on 2025/7/23.
//

import SwiftUI

@main
struct DrumGoApp: App {
    @State private var appModel = AppModel()

    
    var body: some Scene {
        WindowGroup(id: "ContentView") {
            ContentView()
                .environment(appModel)
        }
        .windowResizability(.contentSize)
        .defaultSize(CGSize(width: 200, height: 300))
        
        WindowGroup(id: "SelectView"){
            SelectView()
                .environment(appModel)
        }
        .windowResizability(.contentSize)
        .defaultSize(CGSize(width: 200, height: 300))
        
        WindowGroup(id:"IPModelView",for: String.self){ $modelName in
            IPDetailView(modelName: modelName ?? "IP1")
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 3, height: 3, depth: 3)

        ImmersiveSpace(id: "DrumImmersive") {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        
    }
}
