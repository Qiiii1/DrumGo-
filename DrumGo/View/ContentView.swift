//
//  ContentView.swift
//  DrumGo
//
//  Created by 李棋 on 2025/5/13.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var hasOpened: Bool = false
    
    @Environment(AppModel.self) private var appModel
    
    let images: [String] = ["Album1", "Album2", "Album3", "Album4", "Album5","Album6","Album7","Album8","Album9","Album10"]

    var body: some View {
        
//        CarouselView(images: images)
        ImageScrollView(images:images)
        
        VStack {

            Text("选择歌曲")

            Button {
                Task{
                    dismissWindow(id: "ContentView")
                }
                openWindow(id: "SelectView")
                }label:{
                Text("选择场景和鼓")
            }
        }
        .padding(.bottom,30)
    }
}

struct ImageScrollView: View {
    let images: [String]
    @State private var selectedIndex: Int? = nil
    
    var body: some View {
        ScrollView(.horizontal,showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(images.indices, id: \.self) { idx in
                    Button(action: {
                        if selectedIndex == idx {
                            selectedIndex = nil     // 如果已选中，再点同一张就取消选中
                        } else {
                            selectedIndex = idx     // 选中新的
                        }
                    }) {
                        Image(images[idx])
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .shadow(color: selectedIndex == idx ? Color.accentColor.opacity(0.2) : .clear, radius: 10)
                            .scaleEffect(selectedIndex == idx ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.22), value: selectedIndex)
                            .padding()
                            .scrollTransition{content,phase in
                                content
                                    .opacity(phase.isIdentity ? 1.0 : 0.4)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(32)
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(width:500,height:300)
    }
}



struct CarouselView: View {
    let images: [String] // 你的图片名 ["Album1", ...]
    @State private var currentIndex: Int = 2 // 默认第3张为中心
    @GestureState private var dragOffset: CGFloat = 0

    let spacing: CGFloat = 140
    let angleStep: Double = 30

    func index(_ offset: Int) -> Int {
        // 循环轮播
        let count = images.count
        return (currentIndex + offset + count) % count
    }

    var body: some View {
        ZStack {
            ForEach(-2...2, id: \.self) { offset in
                let idx = index(offset)
                let angle = -Double(offset) * angleStep
                let x = CGFloat(offset) * spacing + dragOffset
                let scale: CGFloat = offset == 0 ? 1.0 : 0.85

                    Image(images[idx])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200 * scale, height: 200 * scale)
                        .rotation3DEffect(
                            .degrees(angle),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .offset(x: x)
                        .shadow(radius: offset == 0 ? 20 : 8)
                        .zIndex(offset == 0 ? 10 : Double(5-abs(offset)))
                        .animation(.easeOut, value: currentIndex)
            }
        }
        .frame(width: 700, height: 250)
        .padding3D(.back,60)
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 20 // 拖动多少就轮播一格
                    if value.translation.width < -threshold {
                        // 向左滑，下一张
                        currentIndex = (currentIndex + 1) % images.count
                    } else if value.translation.width > threshold {
                        // 向右滑，上一张
                        currentIndex = (currentIndex - 1 + images.count) % images.count
                    }
                }
        )
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
