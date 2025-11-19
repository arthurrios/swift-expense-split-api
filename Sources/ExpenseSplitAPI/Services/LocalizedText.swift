//
//  LocalizedText.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Foundation
import Vapor

enum LocalizedText {
    // Cache for parsed xcstrings content
    // Using nonisolated(unsafe) because we manually synchronize with NSLock
    nonisolated(unsafe) private static var cachedStrings: [String: [String: String]]? = nil
    private static let cacheLock = NSLock()
    
    static func string(
        for key: LocalizationKey,
        locale: Locale = .current,
        arguments: [String: String] = [:]
    ) -> String {
        // Try to load from xcstrings file first (works on all platforms)
        if let localizedString = loadFromXcstrings(key: key.rawValue, locale: locale) {
            return replacePlaceholders(in: localizedString, with: arguments)
        }
        
        // Fallback to bundle-based localization (macOS/iOS only)
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
            
            // developmentLocalization is not available on Linux, so we safely access it
            let developmentLocale: String? = {
                #if os(Linux)
                return nil
                #else
                return baseBundle.developmentLocalization
                #endif
            }()
            
            return [
                id,
                id.replacingOccurrences(of: "-", with: "_"),
                id.replacingOccurrences(of: "_", with: "-"),
                language.flatMap { "\($0)" },
                regionless,
                Environment.get("DEFAULT_LOCALE"),
                developmentLocale,
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
    
    // Load localization from .xcstrings JSON file
    private static func loadFromXcstrings(key: String, locale: Locale) -> String? {
        // Load and cache the xcstrings file
        if cachedStrings == nil {
            cacheLock.lock()
            defer { cacheLock.unlock() }
            
            if cachedStrings == nil {
                cachedStrings = parseXcstringsFile()
            }
        }
        
        guard let strings = cachedStrings else { return nil }
        
        // Try locale candidates
        let localeCandidates: [String] = {
            let id = locale.identifier
            return [
                id,
                id.replacingOccurrences(of: "-", with: "_"),
                id.replacingOccurrences(of: "_", with: "-"),
                locale.language.languageCode?.identifier ?? "en",
                Environment.get("DEFAULT_LOCALE") ?? "en",
                "en"
            ]
        }()
        
        // Find the string for this key and locale
        for localeCandidate in localeCandidates {
            if let localeStrings = strings[localeCandidate],
               let value = localeStrings[key] {
                return value
            }
        }
        
        return nil
    }
    
    // Parse the .xcstrings JSON file
    private static func parseXcstringsFile() -> [String: [String: String]]? {
        let baseBundle: Bundle
        #if SWIFT_PACKAGE
        baseBundle = Bundle.module
        #else
        baseBundle = .main
        #endif
        
        // Try to find the xcstrings file
        guard let xcstringsPath = baseBundle.path(forResource: "Localizable", ofType: "xcstrings") else {
            // Try alternative paths (SPM resources location)
            let alternativePaths = [
                baseBundle.resourcePath?.appending("/Localizable.xcstrings"),
                baseBundle.resourcePath?.appending("/ExpenseSplitAPI_ExpenseSplitAPI.resources/Localizable.xcstrings"),
                "/app/ExpenseSplitAPI_ExpenseSplitAPI.resources/Localizable.xcstrings"
            ]
            
            var foundPath: String? = nil
            for path in alternativePaths {
                if let path = path, FileManager.default.fileExists(atPath: path) {
                    foundPath = path
                    break
                }
            }
            
            guard let path = foundPath else {
                return nil
            }
            
            return parseXcstringsFile(at: path)
        }
        
        return parseXcstringsFile(at: xcstringsPath)
    }
    
    private static func parseXcstringsFile(at path: String) -> [String: [String: String]]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any] else {
            return nil
        }
        
        var result: [String: [String: String]] = [:]
        
        // Parse each string entry
        for (key, value) in strings {
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else {
                continue
            }
            
            // Extract translations for each locale
            for (locale, localizationData) in localizations {
                guard let locData = localizationData as? [String: Any],
                      let stringUnit = locData["stringUnit"] as? [String: Any],
                      let stringValue = stringUnit["value"] as? String else {
                    continue
                }
                
                if result[locale] == nil {
                    result[locale] = [:]
                }
                result[locale]?[key] = stringValue
            }
        }
        
        return result
    }
    
    private static func replacePlaceholders(in text: String, with arguments: [String: String]) -> String {
        arguments.reduce(text) { result, pair in
            result.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }
}
