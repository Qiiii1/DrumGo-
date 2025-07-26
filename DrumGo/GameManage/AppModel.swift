//
//  AppModel.swift
//  DrumGo
//
//  Created by 李棋 on 2025/7/23.
//

import SwiftUI


@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "DrumImmersive"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
}
