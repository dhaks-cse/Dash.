//
//  Note.swift
//  Dash
//
//  Created by Trijal Gunaseelan on 11/23/24.
//  Edited by Dhakshika

import SwiftUI
import Combine

struct Note: Identifiable, Codable {

    let id: UUID
    var title: String
    var content: String
    var imageDatas: [Data]?
    var createdAt: Date
    var colorHex: String
    var reminder: Date?
    var isLocked: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        images: [IdentifiableImage] = [],
        createdAt: Date = Date(),
        colorHex: String = "#7C3AED",
        reminder: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.imageDatas = images.map { $0.image.jpegData(compressionQuality: 1.0)! }
        self.createdAt = createdAt
        self.colorHex = colorHex
        self.reminder = reminder
    }

    var images: [IdentifiableImage] {
        get {
            guard let imageDatas = imageDatas else { return [] }
            return imageDatas.compactMap {
                if let image = UIImage(data: $0) {
                    return IdentifiableImage(image: image)
                }
                return nil
            }
        }
        set {
            imageDatas = newValue.map { $0.image.jpegData(compressionQuality: 1.0)! }
        }
    }
}
