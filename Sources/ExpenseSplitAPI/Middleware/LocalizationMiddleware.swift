//
//  LocalizationMiddleware.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Vapor

struct LocalizationMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        request.locale = request.selectLocale()
        return try await next.respond(to: request)
    }
}

extension Request {
    private struct LocaleStorageKey: StorageKey { typealias Value = Locale }

    var locale: Locale {
        get { storage[LocaleStorageKey.self] ?? Locale(identifier: Environment.get("DEFAULT_LOCALE") ?? "en") }
        set { storage[LocaleStorageKey.self] = newValue }
    }
    
    func selectLocale() -> Locale {
        if let header = headers.first(name: .acceptLanguage)?
            .split(separator: ",")
            .map({ $0.split(separator: ";").first?.trimmingCharacters(in: .whitespaces) })
            .compactMap({ $0 })
            .first {
            return Locale(identifier: header)
        }
        if let query = query[String.self, at: "lang"] {
            return Locale(identifier: query)
        }
        return Locale(identifier: Environment.get("DEFAULT_LOCALE") ?? "en")
    }
}
