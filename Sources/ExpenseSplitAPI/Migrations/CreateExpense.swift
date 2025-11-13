//
//  CreateExpense.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Fluent

struct CreateExpense: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("expenses")
            .id()
            .field("name", .string, .required)
            .field("amount_in_cents", .int, .required)
            .field("payer_id", .uuid, .references("users", "id"))
            .field("activity_id", .uuid, .required, .references("activities", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema("expenses").delete()
    }
}
