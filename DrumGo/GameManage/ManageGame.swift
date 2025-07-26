//
//  ManageGame.swift
//  DrumGo
//
//  Created by 李棋 on 2025/5/25.
//

import ARKit
import SwiftUI
import RealityKit
import RealityKitContent

let SNAREDRUM_ENTITY_NAME = "Group"
let TOM1_ENTITY_NAME = "Group_1"
let TOM2_ENTITY_NAME = "Group_2"
let FLOORTOM_ENTITY_NAME = "Group_3"

let CRASHCYMBAL1_ENTITY_NAME = "cha1"
let CRASHCYMBAL2_ENTITY_NAME = "cha2"
let RIDECYMBAL_ENTITY_NAME = "cha3"

let CIRCLE_ENTITY_NAME = "Circle"

let DRUMSTICK_ENTITY_NAME_SUFFIX = "StickSphere"


class GameManager: ObservableObject {
    @Published var selectedSong:Song
    
    var songs:[Song] = []
    
    
    private var tasks:[DispatchWorkItem] = []
    
    static let shared = GameManager()
    let root = Entity()
    
    private var SnareAudio: AudioFileResource?
    private var Tom1Audio: AudioFileResource?
    private var Tom2Audio: AudioFileResource?
    private var FloorTomAudio: AudioFileResource?
    
    private var CrashCymbal1Audio: AudioFileResource?
    private var CrashCymbal2Audio: AudioFileResource?
    private var RideCymbalAudio: AudioFileResource?
    
    
    private var leftHand: Entity?
    private var rightHand: Entity?
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    private var colisionSubs: EventSubscription?
    
    private var drumTemplate: Entity?
    private var boxTemplate: Entity?
    
    
    private init(){
        songs = [
            Song(name: "Missing U", defaultGameScene: .painting)
        ]
        selectedSong = songs[0]
        
        drumTemplate = try? Entity.load(named: "IntactDrumScene",in: realityKitContentBundle)
        if drumTemplate == nil{
            print("Failed to load Drum")
        }
        boxTemplate = try? Entity.load(named: "CircleAnimation", in: realityKitContentBundle)
        if boxTemplate == nil {
            print("Failed to load boxTemplate.")
        }
        
        leftHand = try? Entity.load(named: "DrumStickLeft",in: realityKitContentBundle)
        
        rightHand = try? Entity.load(named: "DrumStick",in: realityKitContentBundle)
        
        Task{
            print("load audio")
            
            SnareAudio = try? await AudioFileResource(named: "MilitaryDrum.MP3",configuration: .init(shouldLoop: false))
            Tom1Audio = try? await AudioFileResource(named: "SoundDrum.MP3",configuration: .init(shouldLoop: false))
            Tom2Audio = try? await AudioFileResource(named: "BassDrum.MP3",configuration: .init(shouldLoop: false))
            FloorTomAudio = try? await AudioFileResource(named: "BassDrum.MP3",configuration: .init(shouldLoop: false))
            
            CrashCymbal1Audio = try? await AudioFileResource(named: "HiHat.MP3",configuration: .init(shouldLoop: false))
            CrashCymbal2Audio = try? await AudioFileResource(named: "CrashCymbal.MP3",configuration: .init(shouldLoop: false))
            RideCymbalAudio = try? await AudioFileResource(named: "RideCymbal.MP3",configuration: .init(shouldLoop: false))
        }
    }
    
    
    func start(){
        self.selectedSong.player.numberOfLoops = 0
        self.selectedSong.player.currentTime = 0
        
        self.selectedSong.player.play()
        
        self.scheduleTasks(notes: self.selectedSong.stage.notes, startTime: DispatchTime.now())
        
        
        Task{
            if HandTrackingProvider.isSupported && handTracking.state == .initialized{
                try await self.session.run([self.handTracking])
                await self.processHandUpdates()
            }
        }
    }
    
    
    func placeDrum() -> Entity{
            guard let drumTemplate = drumTemplate else{
                fatalError("Can't find drumTemplate")
            }
            
            root.addChild(drumTemplate)
            
            return drumTemplate
        }
    
    func spawnBox(note: Note) -> Entity {
        guard let boxTemplate = boxTemplate else {
            fatalError("Box template is nil")
        }
        let box = boxTemplate.clone(recursive: true)
        
        let start = generateStart(note: note)
        box.position = simd_float(start.vector + .init(x: 0, y: 0, z: -2))
        
        let animation = generateBoxMovementAnimation(start: start)
        
        box.playAnimation(animation, transitionDuration: 1.0, startsPaused: false)
        
        root.addChild(box)
        return box
    }
    
    private func scheduleTasks(notes: [Note], startTime: DispatchTime) {
        for note in notes {
            let createTask = DispatchWorkItem {
                let box = self.spawnBox(note: note)
                let destroyTask = DispatchWorkItem {
                    box.removeFromParent()
                }
                self.tasks.append(destroyTask)
                DispatchQueue.main.asyncAfter(deadline: .now() + BoxSpawnParameters.lifeTime) {
                    destroyTask.perform()
                }
            }
            tasks.append(createTask)
            DispatchQueue.main.asyncAfter(deadline: startTime + note.time * 0.5 - BoxSpawnParameters.lifeTime / 2) {
                createTask.perform()
            }
        }
    }
        
    func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            let handAnchor = update.anchor
            
                guard
                    handAnchor.isTracked,
                    let handEntity = handAnchor.handSkeleton?.joint(.middleFingerKnuckle),
                    handEntity.isTracked else { continue }
                
                let originFromIndexFingerTip = handAnchor.originFromAnchorTransform * handEntity.anchorFromJointTransform
                
                var entity: Entity!
            
                if handAnchor.chirality == .left {
                    entity = leftHand
                } else {
                    entity = rightHand
                }
            
                if await entity.parent == nil {
                    await root.addChild(entity)
                }
                  
                await entity.setTransformMatrix(originFromIndexFingerTip, relativeTo: nil)
                
            }
        }
        
    func handleSnarePunch(drum: Entity) {
        guard let parent = drum.parent else {
            print("找不到鼓的父节点")
            return
        }
        guard let audio = SnareAudio else {
            print("音效资源加载失败")
            return
        }
        guard let audioEntity = parent.findEntity(named: "Snare") else {
            print("找不到 Snare 实体")
            return
        }

        print("准备播放音效")
        parent.stopAllAnimations()
        audioEntity.playAudio(audio)
        
        if let scene = drum.scene{
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "SnareCollision"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "HeartAnimation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "LightShowAnimation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "Heart2Animation"
                ]
            )
        }
    }
    
    func handleTom1Punch(drum: Entity) {
        guard let parent = drum.parent else {
            print("找不到鼓的父节点")
            return
        }
        guard let audio = Tom1Audio else {
            print("音效资源加载失败")
            return
        }
        guard let audioEntity = parent.findEntity(named: "Tom1") else {
            print("找不到 Tom1 实体")
            return
        }

        print("准备播放音效")
        parent.stopAllAnimations()
        audioEntity.playAudio(audio)
        
        if let scene = drum.scene{
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "Tom1Collision"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "HeartAnimation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "LightShowAnimation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "Heart1Animation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "Heart2Animation"
                ]
            )
        }
        
        
    }
    
    func handleTom2Punch(drum: Entity) {
        guard let parent = drum.parent else {
            print("找不到鼓的父节点")
            return
        }
        guard let audio = Tom2Audio else {
            print("音效资源加载失败")
            return
        }
        guard let audioEntity = parent.findEntity(named: "Tom2") else {
            print("找不到 Tom2 实体")
            return
        }

        print("准备播放音效")
        parent.stopAllAnimations()
        audioEntity.playAudio(audio)
        
        if let scene = drum.scene{
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "Tom2Collision"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "HeartAnimation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "Heart2Animation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "LightShowAnimation"
                ]
            )
        }
    }
    
    func handleFloorTomPunch(drum: Entity) {
        guard let parent = drum.parent else {
            print("找不到鼓的父节点")
            return
        }
        guard let audio = FloorTomAudio else {
            print("音效资源加载失败")
            return
        }
        guard let audioEntity = parent.findEntity(named: "FloorTom") else {
            print("找不到 FloorTom 实体")
            return
        }

        print("准备播放音效")
        parent.stopAllAnimations()
        audioEntity.playAudio(audio)
        
        if let scene = drum.scene{
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "FloorTomCollision"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "Heart1Animation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "HeartAnimation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "LightShowAnimation"
                ]
            )
        }
    }
    
    func handleCrashCymbal1Punch(drum: Entity) {
        guard let parent = drum.parent else {
            print("找不到鼓的父节点")
            return
        }
        guard let audio = CrashCymbal1Audio else {
            print("音效资源加载失败")
            return
        }
        guard let audioEntity = parent.findEntity(named: "CrashCymbal1") else {
            print("找不到 CrashCymbal1 实体")
            return
        }

        print("准备播放音效")
        parent.stopAllAnimations()
        audioEntity.playAudio(audio)
        
        if let scene = drum.scene{
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "CrashCymbal1Collision"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "HeartAnimation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "Heart2Animation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "LightShowAnimation"
                ]
            )
        }
    }
    
    func handleCrashCymbal2Punch(drum: Entity) {
        guard let parent = drum.parent else {
            print("找不到鼓的父节点")
            return
        }
        guard let audio = CrashCymbal2Audio else {
            print("音效资源加载失败")
            return
        }
        guard let audioEntity = parent.findEntity(named: "CrashCymbal2") else {
            print("找不到 CrashCymbal2 实体")
            return
        }

        print("准备播放音效")
        parent.stopAllAnimations()
        audioEntity.playAudio(audio)
        
        if let scene = drum.scene{
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "CrashCymbal2Collision"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "Heart1Animation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "HeartAnimation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "LightShowAnimation"
                ]
            )
        }
    }
    
    func handleRideCymbalPunch(drum: Entity) {
        guard let parent = drum.parent else {
            print("找不到鼓的父节点")
            return
        }
        guard let audio = RideCymbalAudio else {
            print("音效资源加载失败")
            return
        }
        guard let audioEntity = parent.findEntity(named: "RideCymbal") else {
            print("找不到 RideCymbal 实体")
            return
        }

        print("准备播放音效")
        parent.stopAllAnimations()
        audioEntity.playAudio(audio)
        
        if let scene = drum.scene{
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "RideCymbalCollision"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "HeartAnimation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "Heart2Animation"
                ]
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("RealityKit.NotificationTrigger"),
                object: nil,
                userInfo: [
                    "RealityKit.NotificationTrigger.Scene": scene,
                    "RealityKit.NotificationTrigger.Identifier": "LightShowAnimation"
                ]
            )
        }
    }
    
    func handleCirclePunch(drum: Entity) {
        guard let parent = drum.parent,
        let particleEmitter = parent.findEntity(named: "ParticleEmitter") else {
            print("找不到鼓的父节点")
            return
        }
        parent.stopAllAnimations()
        
        particleEmitter.components[ParticleEmitterComponent.self]?.burst()
        drum.removeFromParent()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            parent.removeFromParent()
        }
    }
        
    func handleSnareCollision(content:RealityViewContent){
            colisionSubs = content.subscribe(to: CollisionEvents.Began.self){ collisionEvents in
                let a = collisionEvents.entityA
                let b = collisionEvents.entityB
                print("碰撞事件: \(a.name) <-> \(b.name)")
                var drum: Entity!
                if a.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX) && b.name == SNAREDRUM_ENTITY_NAME {
                    drum = b
                } else if a.name == SNAREDRUM_ENTITY_NAME && b.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX){
                    drum = a
                } else{
                    return
                }
                
                print("检测到鼓棒和鼓碰撞，准备播放音效")
                
                self.handleSnarePunch(drum: drum)
            }
        }
    
    func handleTom1Collision(content:RealityViewContent){
            colisionSubs = content.subscribe(to: CollisionEvents.Began.self){ collisionEvents in
                let a = collisionEvents.entityA
                let b = collisionEvents.entityB
                print("碰撞事件: \(a.name) <-> \(b.name)")
                var drum: Entity!
                if a.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX) && b.name == TOM1_ENTITY_NAME {
                    drum = b
                } else if a.name == TOM1_ENTITY_NAME && b.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX){
                    drum = a
                } else{
                    return
                }
                
                print("检测到鼓棒和鼓碰撞，准备播放音效")
                
                self.handleTom1Punch(drum: drum)
            }
        }
    
    func handleTom2Collision(content:RealityViewContent){
            colisionSubs = content.subscribe(to: CollisionEvents.Began.self){ collisionEvents in
                let a = collisionEvents.entityA
                let b = collisionEvents.entityB
                print("碰撞事件: \(a.name) <-> \(b.name)")
                var drum: Entity!
                if a.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX) && b.name == TOM2_ENTITY_NAME {
                    drum = b
                } else if a.name == TOM2_ENTITY_NAME && b.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX){
                    drum = a
                } else{
                    return
                }
                
                print("检测到鼓棒和鼓碰撞，准备播放音效")
                
                
                
                self.handleTom2Punch(drum: drum)
            }
        }
    
    func handleFloorTomCollision(content:RealityViewContent){
            colisionSubs = content.subscribe(to: CollisionEvents.Began.self){ collisionEvents in
                let a = collisionEvents.entityA
                let b = collisionEvents.entityB
                print("碰撞事件: \(a.name) <-> \(b.name)")
                var drum: Entity!
                if a.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX) && b.name == FLOORTOM_ENTITY_NAME {
                    drum = b
                } else if a.name == FLOORTOM_ENTITY_NAME && b.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX){
                    drum = a
                } else{
                    return
                }
                
                print("检测到鼓棒和鼓碰撞，准备播放音效")
                
                self.handleFloorTomPunch(drum: drum)
            }
        }
    
    func handleCrashCymbal1Collision(content:RealityViewContent){
            colisionSubs = content.subscribe(to: CollisionEvents.Began.self){ collisionEvents in
                let a = collisionEvents.entityA
                let b = collisionEvents.entityB
                print("碰撞事件: \(a.name) <-> \(b.name)")
                var drum: Entity!
                if a.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX) && b.name == CRASHCYMBAL1_ENTITY_NAME {
                    drum = b
                } else if a.name == CRASHCYMBAL1_ENTITY_NAME && b.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX){
                    drum = a
                } else{
                    return
                }
                
                print("检测到鼓棒和鼓碰撞，准备播放音效")
                
                self.handleCrashCymbal1Punch(drum: drum)
            }
        }
    
    func handleCrashCymbal2Collision(content:RealityViewContent){
            colisionSubs = content.subscribe(to: CollisionEvents.Began.self){ collisionEvents in
                let a = collisionEvents.entityA
                let b = collisionEvents.entityB
                print("碰撞事件: \(a.name) <-> \(b.name)")
                var drum: Entity!
                if a.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX) && b.name == CRASHCYMBAL2_ENTITY_NAME {
                    drum = b
                } else if a.name == CRASHCYMBAL2_ENTITY_NAME && b.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX){
                    drum = a
                } else{
                    return
                }
                
                print("检测到鼓棒和鼓碰撞，准备播放音效")
                
                self.handleCrashCymbal2Punch(drum: drum)
            }
        }
    
    func handleRideCymbalCollision(content:RealityViewContent){
            colisionSubs = content.subscribe(to: CollisionEvents.Began.self){ collisionEvents in
                let a = collisionEvents.entityA
                let b = collisionEvents.entityB
                print("碰撞事件: \(a.name) <-> \(b.name)")
                var drum: Entity!
                if a.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX) && b.name == RIDECYMBAL_ENTITY_NAME {
                    drum = b
                } else if a.name == RIDECYMBAL_ENTITY_NAME && b.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX){
                    drum = a
                } else{
                    return
                }
                
                print("检测到鼓棒和鼓碰撞，准备播放音效")
                
                self.handleRideCymbalPunch(drum: drum)
            }
        }
    
    func handleCircleCollision(content:RealityViewContent){
            colisionSubs = content.subscribe(to: CollisionEvents.Began.self){ collisionEvents in
                let a = collisionEvents.entityA
                let b = collisionEvents.entityB
                print("碰撞事件: \(a.name) <-> \(b.name)")
                var drum: Entity!
                if a.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX) && b.name == CIRCLE_ENTITY_NAME {
                    drum = b
                } else if a.name == CIRCLE_ENTITY_NAME && b.name.hasSuffix(DRUMSTICK_ENTITY_NAME_SUFFIX){
                    drum = a
                } else{
                    return
                }
                
                print("检测到鼓棒和鼓碰撞，准备播放音效")
                
                self.handleCirclePunch(drum: drum)
            }
        }
    
    func createLargeSkybox(named textureName: String) -> Entity? {
        let largeSphere = MeshResource.generateSphere(radius: 30)
        var skyboxMaterial = UnlitMaterial()
        
        do {
            let texture = try TextureResource.load(named: textureName)
            skyboxMaterial.color = .init(texture: .init(texture))
        } catch {
            print("Failed to load texture named \(textureName)")
            return nil
        }
        
        let skyboxEntity = Entity()
        skyboxEntity.components.set(ModelComponent(mesh: largeSphere, materials: [skyboxMaterial]))
        skyboxEntity.scale = .init(x: -20, y: 20, z: 20)
        
        return skyboxEntity
    }
    
    func generateBoxMovementAnimation(start: Point3D) -> AnimationResource {
        let fromTransform = Transform(
            scale: SIMD3<Float>(repeating: 0.1), // 初始缩放很小
            translation: SIMD3<Float>(0, 0, -2)  // 用户面前两米
        )
        let toTransform = Transform(
            scale: SIMD3<Float>(repeating: 1.0), // 变大到正常
            translation: simd_float(start.vector) // 目标点
        )

        let animation = try! AnimationResource.generate(
            with: FromToByAnimation<Transform>(
                name: "moveAndScaleUp",
                from: fromTransform,
                to: toTransform,
                duration: 3.0,
                bindTarget: .transform
            )
        )
        return animation
    }
    
    
    
    }

