//
//  DateFormatter.swift
//  Formatter
//
//  Created by Blair Mitchelmore on 2025-07-31.
//

import Foundation

protocol DateFormatter: Sendable {
    func string(from date: Date) -> String
}

extension Foundation.DateFormatter: DateFormatter {}
extension ISO8601DateFormatter: DateFormatter {}

func BuildDateFormatter(for identifier: String?) -> any DateFormatter {
    guard let identifier = identifier else {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSS'Z'"
        return formatter
    }
    
    let formatter = Foundation.DateFormatter()
    switch identifier {
    case "iso8601":
        return ISO8601DateFormatter()
    case "short":
        formatter.dateStyle = .short
        formatter.timeStyle = .short
    case "medium":
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
    case "long":
        formatter.dateStyle = .long
        formatter.timeStyle = .long
    case "full":
        formatter.dateStyle = .full
        formatter.timeStyle = .full
    default:
        formatter.dateFormat = identifier
    }
    return formatter
}
