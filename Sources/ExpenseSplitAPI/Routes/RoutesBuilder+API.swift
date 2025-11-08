//
//  RoutesBuilder+API.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 08/11/25.
//

import Vapor
import VaporToOpenAPI

extension RoutesBuilder {
    /// All version‑1 endpoints live under `/api/v1`
    var apiV1: any RoutesBuilder { grouped("api", "v1") }
    
    /// Convenience for a resource group (e.g. `/api/v1/users`)
    func apiV1Group(
        _ path: PathComponent...,
        tags: [TagObject] = [],
        auth: [AuthSchemeObject] = []
    ) -> any RoutesBuilder {
        var builder = apiV1.grouped(path)
        if !tags.isEmpty { builder = builder.groupedOpenAPI(tags: tags) }
        if !auth.isEmpty { builder = builder.groupedOpenAPI(auth: auth) }
        return builder
    }
}
