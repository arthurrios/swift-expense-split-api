//
//  Expense.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 06/11/25.
//

import Vapor
import Fluent

final class Expense: Model, Content, @unchecked Sendable {
    static let schema = "expenses"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "amount_in_cents")
    var amountInCents: Int
    
    @OptionalParent(key: "payer_id")
    var payer: User?
    
    @Parent(key: "activity_id")
    var activity: Activity
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    // Relationships
    @Siblings(through: ExpenseParticipant.self, from: \.$expense, to: \.$user)
    var participants: [User]
    
    @Children(for: \.$expense)
    var payments: [ExpensePayment]
    
    init() {}
    
    init(id: UUID? = nil,
         name: String,
         amountInCents: Int,
         payerID: UUID? = nil,
         activityID: UUID) {
        self.id = id
        self.name = name
        self.amountInCents = amountInCents
        self.$payer.id = payerID
        self.$activity.id = activityID
    }
}

// MARK: - Pivot Table for Expense-User Relationship (debtors)
final class ExpenseParticipant: Model, @unchecked Sendable {
    static let schema = "expense_participants"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "expense_id")
    var expense: Expense
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "amount_owed_in_cents")
    var amountOwedInCents: Int
    
    @Timestamp(key: "added_at", on: .create)
    var addedAt: Date?
    
    init() {}
    
    init(id: UUID? = nil,
         expenseID: UUID,
         userID: UUID,
         amountOwedInCents: Int) {
        self.id = id
        self.$expense.id = expenseID
        self.$user.id = userID
        self.amountOwedInCents = amountOwedInCents
    }
}

// MARK: - Track Payments Made by Debtors
final class ExpensePayment: Model, Content, @unchecked Sendable {
    static let schema = "expense_payments"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "expense_id")
    var expense: Expense
    
    @Parent(key: "debtor_id")
    var debtor: User
    
    @Field(key: "amount_paid_in_cents")
    var amountPaidInCents: Int
    
    @Timestamp(key: "paid_at", on: .create)
    var paidAt: Date?
    
    init() {}
    
    init(id: UUID? = nil,
         expenseID: UUID,
         debtorID: UUID,
         amountPaidInCents: Int) {
        self.id = id
        self.$expense.id = expenseID
        self.$debtor.id = debtorID
        self.amountPaidInCents = amountPaidInCents
    }
}
