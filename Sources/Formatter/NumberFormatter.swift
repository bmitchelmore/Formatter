//
//  NumberFormatter.swift
//  Formatter
//
//  Created by Blair Mitchelmore on 2025-08-24.
//

import Foundation

private enum NumberFormatterStyleId: String {
    case decimal = "d"
    case currency = "c"
    case percent = "pct"
    case scientific = "sci"
    case spellOut = "so"
    case ordinal = "ord"
    case currencyISOCode = "ciso"
    case currencyPlural = "cpl"
    case currencyAccounting = "cac"
    
    var style: NumberFormatter.Style {
        switch self {
        case .decimal:
            .decimal
        case .currency:
            .currency
        case .percent:
            .percent
        case .scientific:
            .scientific
        case .spellOut:
            .spellOut
        case .ordinal:
            .ordinal
        case .currencyISOCode:
            .currencyISOCode
        case .currencyPlural:
            .currencyPlural
        case .currencyAccounting:
            .currencyAccounting
        }
    }
}

func BuildNumberFormatter(for identifier: String?) -> NumberFormatter {
    if let identifier, let id = NumberFormatterStyleId(rawValue: identifier) {
        let formatter = NumberFormatter()
        formatter.numberStyle = id.style
        return formatter
    }
    let formatter = NumberFormatter()
    // we can include more customization based
    // on identifier here in the future
    return formatter
}

