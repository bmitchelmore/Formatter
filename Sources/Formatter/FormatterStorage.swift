//
//  FormatterStorage.swift
//  Formatter
//
//  Created by Blair Mitchelmore on 2025-07-31.
//

import Foundation
import os

final class FormatterStorage<T>: @unchecked Sendable {
    private let lock: OSAllocatedUnfairLock<[String?:T]>
    private let builder: (String?) -> T
    
    init(builder: @escaping (String?) -> T) {
        self.lock = OSAllocatedUnfairLock(uncheckedState: [:])
        self.builder = builder
    }
    
    subscript(_ identifier: String?) -> T {
        get {
            lock.withLockUnchecked { formatters in
                if let formatter = formatters[identifier] {
                    return formatter
                } else {
                    let formatter = builder(identifier)
                    formatters[identifier] = formatter
                    return formatter
                }
            }
        }
    }
}

func DateFormatterStorage() -> FormatterStorage<DateFormatter> {
    return FormatterStorage(builder: BuildDateFormatter)
}

func NumberFormatterStorage() -> FormatterStorage<NumberFormatter> {
    return FormatterStorage(builder: BuildNumberFormatter)
}
