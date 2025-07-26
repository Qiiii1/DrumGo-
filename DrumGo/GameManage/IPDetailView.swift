//
//  IPDetailView.swift
//  DrumGo
//
//  Created by 李棋 on 2025/7/4.
//

import SwiftUI
import _RealityKit_SwiftUI
import RealityKitContent

struct IPDetailView: View {
    let modelName: String
    
    var body: some View {
        Model3D(named: modelName, bundle: realityKitContentBundle)
            .gesture(TapGesture().targetedToAnyEntity())
            .frame(depth: 150)
        
            
    }
}

#Preview {
    IPDetailView(modelName: "AngryScene")
}
