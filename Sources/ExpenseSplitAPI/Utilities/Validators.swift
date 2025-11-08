//
//  Validators.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Foundation

enum Validators {
    static func isValidEmail(_ value: String) -> Bool {
        // Case-insensitive regex; rebuilt on each call to avoid Sendable warnings
        let pattern = #"(?i)^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        guard let regex = try? Regex(pattern) else {
            return false
        }
        return value.wholeMatch(of: regex) != nil
    }
}
