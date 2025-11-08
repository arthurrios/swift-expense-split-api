//
//  LocalizedAbortError.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Vapor
import Foundation

struct LocalizedAbortError: AbortError {
    let status: HTTPResponseStatus
    let key: LocalizationKey
    let arguments: [String: String]
    let locale: Locale
    
    var reason: String {
        LocalizedText.string(for: key, locale: locale, arguments: arguments)
    }
    
    var errorDescription: String? {
        reason
    }
}
