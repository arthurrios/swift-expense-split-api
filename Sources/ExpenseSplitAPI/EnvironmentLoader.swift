//
//  EnvironmentLoader.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Foundation
import Vapor

/// Helper to load environment variables from .env files
enum EnvironmentLoader {
    static func loadEnvironmentFile(_ app: Application) throws {
        let environment = app.environment
        
        // Determine which .env file to load
        let envFileName: String
        switch environment {
        case .production:
            envFileName = ".env.production"
        case .testing:
            envFileName = ".env.testing"
        case .development:
            envFileName = ".env.development"
        default:
            envFileName = ".env.development"
        }
        
        // Use working directory (set in Xcode scheme or current directory)
        let workingDirectory = app.directory.workingDirectory
        let envFileURL = URL(fileURLWithPath: workingDirectory)
            .appendingPathComponent(envFileName)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: envFileURL.path) else {
            app.logger.warning("⚠️  Environment file '\(envFileName)' not found at \(envFileURL.path)")
            app.logger.info("📝 Using system environment variables instead")
            return
        }
        
        // Read and parse file
        guard let fileContents = try? String(contentsOf: envFileURL, encoding: .utf8) else {
            app.logger.error("❌ Failed to read environment file: \(envFileName)")
            return
        }
        
        // Parse and set environment variables
        var loadedCount = 0
        var skippedCount = 0
        var invalidLines = 0
        
        for (lineNumber, line) in fileContents.components(separatedBy: .newlines).enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else { continue }
            
            // Parse KEY=VALUE
            let parts = trimmedLine.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else {
                invalidLines += 1
                continue
            }
            
            let key = String(parts[0].trimmingCharacters(in: .whitespaces))
            var value = String(parts[1].trimmingCharacters(in: .whitespaces))
            
            // Skip if key is empty
            guard !key.isEmpty else {
                invalidLines += 1
                continue
            }
            
            // Remove quotes if present
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            
            // Always set from .env file (override system environment)
            // Use setenv which will override existing values
            setenv(key, value, 1)  // 1 = overwrite existing
            loadedCount += 1
        }
        
        app.logger.info("✅ Loaded \(loadedCount) environment variables from \(envFileName)")
        if invalidLines > 0 {
            app.logger.warning("⚠️  Skipped \(invalidLines) invalid lines in \(envFileName)")
        }
    }
}
