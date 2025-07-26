//
//  GameScene.swift
//  DrumGo
//
//  Created by 李棋 on 2025/6/15.
//

import Foundation

enum GameScene: String, CaseIterable, Identifiable {
    case cyberpunk = "Cyberpunk"
    case painting = "VanGogh"
    case cartoon = "Cartoon"
    
    var id: String {
        self.rawValue
    }
}
