//
//  CreateExpensePayments.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Fluent

struct CreateExpensePayments: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("expense_payments")
            .id()
            .field("expense_id", .uuid, .required, .references("expenses", "id", onDelete: .cascade))
            .field("debtor_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("amount_paid_in_cents", .int, .required)
            .field("paid_at", .datetime)
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema("expense_payments").delete()
    }
}
