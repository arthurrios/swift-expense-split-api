//
//  CreateActivity.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Fluent

struct CreateActivity: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("activities")
            .id()
            .field("name", .string, .required)
            .field("activity_date", .datetime, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema("activities").delete()
    }
}
