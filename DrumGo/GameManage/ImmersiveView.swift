//
//  ImmersiveView.swift
//  DrumGo
//
//  Created by 李棋 on 2025/5/13.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {
    
    @StateObject var gameManager: GameManager = GameManager.shared
    
    @State var session = ARKitSession()
    @State var handTracking = HandTrackingProvider()
    @State private var authorizationError:Error?
    @State var root = Entity()
    @State var drumStickEntity:Entity?
    @State var drumEntity:Entity?
    @State var StickSphereEntity:Entity?
    
    private var colisionSubs: EventSubscription?
    
    

    var body: some View {
        RealityView { content in
            if let immersiveContentEntity = try? await Entity(named: "IntactDrumScene", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
                
                content.add(gameManager.root)
                
                gameManager.handleCrashCymbal1Collision(content: content)
                gameManager.handleCrashCymbal2Collision(content: content)
                gameManager.handleRideCymbalCollision(content: content)
                
                gameManager.handleTom1Collision(content: content)
                gameManager.handleTom2Collision(content: content)
                gameManager.handleSnareCollision(content: content)
                gameManager.handleFloorTomCollision(content: content)
                
                gameManager.handleCircleCollision(content: content)
                
//                if let skybox = gameManager.createLargeSkybox(named: "DarkTexture"){
//                    skybox.name = "Skybox"
//                    content.add(skybox)
//                }
                
                
            }
        }
        .onAppear(){
            gameManager.start()
        }
        .gesture(
            SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded{value in
                gameManager.handleTom1Punch(drum: value.entity)
                gameManager.handleTom2Punch(drum: value.entity)
                gameManager.handleSnarePunch(drum: value.entity)
                gameManager.handleFloorTomPunch(drum: value.entity)
                
                gameManager.handleRideCymbalPunch(drum: value.entity)
                gameManager.handleCrashCymbal1Punch(drum: value.entity)
                gameManager.handleCrashCymbal2Punch(drum: value.entity)
                
                gameManager.handleCirclePunch(drum: value.entity)
            }
        )
    }
    }

#Preview() {
    ImmersiveView()
        .environment(AppModel())
}
