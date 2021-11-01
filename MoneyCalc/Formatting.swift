//
//  Formatting.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-30.
//

import Foundation
import SwiftUI

extension URL {
    var formatted: String {
        (host ?? "").replacingOccurrences(of: "www.", with: "")
    }
}

extension Date {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension Color {
    static var teal: Color {
        Color(UIColor.systemTeal)
    }
}
