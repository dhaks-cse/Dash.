//
//  Color+Hex.swift
//  Dash
//
//  Created by Dhakshika K S on 03/04/26.
//

import SwiftUI

extension Color {

    init(hex: String) {

        var hex = hex

        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        guard let int = UInt64(hex, radix: 16) else {
            self = .clear
            return
        }

        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {

        let uiColor = UIColor(self)

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0

        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)

        return String(
            format: "#%02lX%02lX%02lX",
            Int(r*255),
            Int(g*255),
            Int(b*255)
        )
    }
}
