//
//  SelectView.swift
//  DrumGo
//
//  Created by 李棋 on 2025/7/1.
//

import SwiftUI

struct SelectView: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    
    @Environment(AppModel.self) private var appModel
    
    @State private var selectedTab: Int = 0 // 0: 架子鼓  1: 场景
    @State private var selectedIndex: Int? = nil

    let drumImages = ["Drum1", "Drum2", "Drum3", "Drum4", "Drum5", "Drum6"]
    let sceneImages = ["Scene 1", "Scene 2", "Scene 3", "Scene 4", "Scene 5", "Scene 6"]
    let IPModels = ["IP1","IP2"]

    var images: [String] {
        selectedTab == 0 ? drumImages : sceneImages
    }
    
    var body: some View {
       
        ScrollView(.vertical){
            VStack{
                VStack(spacing: 20) {
                    // TabBar
                    
                    Picker("", selection: $selectedTab) {
                                    Text("架子鼓").tag(0)
                                    Text("场景").tag(1)
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 3), spacing: 32) {
                                    ForEach(images.indices, id: \.self) { idx in
                                        Button(action: {
                                            selectedIndex = idx
                                        }) {
                                            ZStack {
                                                if selectedIndex == idx {
                                                    RoundedRectangle(cornerRadius: 23)
                                                        .fill(Color.black.opacity(0.5))
                                                        
                                                }
                                                Image(images[idx])
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(height: 90)
                                                    .cornerRadius(18)
                                                // 选中态黑色蒙层
                                            }
                                            .frame(height: 110)
                                        }
                                        .buttonStyle(.plain) // 防止Button自带高亮变灰
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .frame(height: 300)
                    
                }
                HStack{
                    Button{
                        openWindow(id: "IPModelView",value: IPModels[0])
                    }label: {
                        Text("RedIP")
                    }
                    
                    Button{
                        openWindow(id: "IPModelView",value: IPModels[1])
                    }label: {
                        Text("GreenIP")
                    }
                }
                
                Button {
                    Task { @MainActor in
                        switch appModel.immersiveSpaceState {
                            case .open:
                                appModel.immersiveSpaceState = .inTransition
                                await dismissImmersiveSpace()
                            case .closed:
                                appModel.immersiveSpaceState = .inTransition
                                switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                                    case .opened:
                                        break

                                    case .userCancelled, .error:
                                        fallthrough
                                    @unknown default:
                                        appModel.immersiveSpaceState = .closed
                                }

                            case .inTransition:
                                break
                        }
                    }
                } label: {
                    Text(appModel.immersiveSpaceState == .open ? "Quilt" : "Go!")
                }
                .disabled(appModel.immersiveSpaceState == .inTransition)
                .animation(.easeInOut, value: 0)
                .fontWeight(.semibold)
                .padding(20)
            }
        }.frame(width: 400, height: 600, alignment: .center)
    }
}
 

#Preview {
    SelectView()
        .environment(AppModel())
}
