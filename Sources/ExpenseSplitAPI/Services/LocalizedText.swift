//
//  LocalizedText.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Foundation
import Vapor

enum LocalizedText {
    static func string(
        for key: LocalizationKey,
        locale: Locale = .current,
        arguments: [String: String] = [:]
    ) -> String {
        let baseBundle: Bundle
        #if SWIFT_PACKAGE
        baseBundle = Bundle.module
        #else
        baseBundle = .main
        #endif
        
        // Try the exact locale, then a few fallbacks, then default.
        let candidates: [String] = {
            let id = locale.identifier
            let language = locale.language.languageCode?.identifier
            let regionless = id.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
            
            return [
                id,
                id.replacingOccurrences(of: "-", with: "_"),
                id.replacingOccurrences(of: "_", with: "-"),
                language.flatMap { "\($0)" },
                regionless,
                Environment.get("DEFAULT_LOCALE"),
                baseBundle.developmentLocalization,
                "en"
            ].compactMap { $0 }
        }()
        
        for candidate in candidates {
            if let bundlePath = baseBundle.path(forResource: candidate, ofType: "lproj"),
               let localizedBundle = Bundle(path: bundlePath) {
                let localized = localizedBundle.localizedString(forKey: key.rawValue, value: nil, table: nil)
                if localized != key.rawValue || candidate == candidates.last {
                    return replacePlaceholders(in: localized, with: arguments)
                }
            }
        }
        
        return replacePlaceholders(in: key.rawValue, with: arguments)
    }
    
    private static func replacePlaceholders(in text: String, with arguments: [String: String]) -> String {
        arguments.reduce(text) { result, pair in
            result.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }
}
