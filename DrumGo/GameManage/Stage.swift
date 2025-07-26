//
//  Stage.swift
//  DrumGo
//
//  Created by 李棋 on 2025/7/23.
//

import RealityKit
import Spatial

// 定义主模型
struct Stage: Decodable {
    let version: String
    let events: [String] // 假设 events 是一个字符串数组，根据实际情况调整
    let notes: [Note]
    let obstacles: [Obstacle]

    // 自定义键名映射
    enum CodingKeys: String, CodingKey {
        case version = "_version"
        case events = "_events"
        case notes = "_notes"
        case obstacles = "_obstacles"
    }
}

// 定义 Note 模型
struct Note: Decodable {
    enum LineIndex: Int, Decodable {
        case leftmost = 0
        case left = 1
        case right = 2
        case rightmost = 3

        var column: BeatmapColumn {
            switch self {
            case .leftmost:
                return .leftmost
            case .left:
                return .left
            case .right:
                return .right
            case .rightmost:
                return .rightmost
            }
        }
    }
    
    enum LineLayer: Int, Decodable {
        case bottom = 1
        case top = 2

        var row: BeatmapRow {
            switch self {
            case .bottom:
                return .bottom
            case .top:
                return .top
            }
        }
    }

    let time: Double
    let lineIndex: LineIndex
    let lineLayer: LineLayer
    let type: Int
    let cutDirection: Int

    // 自定义键名映射
    enum CodingKeys: String, CodingKey {
        case time = "_time"
        case lineIndex = "_lineIndex"
        case lineLayer = "_lineLayer"
        case type = "_type"
        case cutDirection = "_cutDirection"
    }
}

// 节奏所在列
public enum BeatmapColumn: Int {
    case leftmost = 0
    case left = 1
    case right = 2
    case rightmost = 3
}

// 节奏所在行
public enum BeatmapRow: Int {
    case bottom = 1
    case top = 2
}

// 定义 Obstacle 模型
struct Obstacle: Codable {
    let time: Double
    let lineIndex: Int
    let type: Int
    let duration: Double
    let width: Int

    // 自定义键名映射
    enum CodingKeys: String, CodingKey {
        case time = "_time"
        case lineIndex = "_lineIndex"
        case type = "_type"
        case duration = "_duration"
        case width = "_width"
    }
}

/**
 * 音符处理方法
 */
func generateStart(note: Note) -> Point3D {
    // 默认值
    var x = 0.0
    var y = 0.0
    var z = 0.0

    switch (note.lineLayer.rawValue, note.lineIndex.rawValue) {
    case (1, 0):
        x = -0.55; y = 0.64; z = -0.52
    case (1, 1):
        x = -0.15; y = 0.76; z = -0.83
    case (1, 2):
        x = 0.2; y = 0.76; z = -0.83
    case (1, 3):
        x = 0.51; y = 0.60; z = -0.44
    case (2, 0):
        x = -0.86; y = 0.83; z = -0.78
    case (2, 1):
        x = -0.46; y = 1.06; z = -1.04
    case (2, 2):
        x = 0.58; y = 1.04; z = -0.93
    default:
        x = 0; y = 0; z = 0
    }

    // 单位换算：cm -> m
    return Point3D(
        x: x,
        y: y,
        z: z
    )
}

func generateBoxMovementAnimation(start: Point3D) -> AnimationResource {
    let fromTransform = Transform(
        scale: SIMD3<Float>(repeating: 0.1), // 初始缩放很小
        translation: SIMD3<Float>(0, 1, -2)  // 用户面前两米
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

enum BoxSpawnParameters {
    static var deltaX = 0.02
    static var deltaY = -0.12
    static var deltaZ = 12.0

    static var lifeTime = 3.0
}
