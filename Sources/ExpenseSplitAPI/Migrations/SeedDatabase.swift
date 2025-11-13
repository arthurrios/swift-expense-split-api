//
//  SeedDatabase.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Fluent
import Vapor

struct SeedDatabase: AsyncMigration {
    func prepare(on database: any Database) async throws {
        // Check if seed has already been run
        let existingUsers = try await User.query(on: database).count()
        if existingUsers > 0 {
            return
        }
        
        print("🌱 [SEED] Seeding database...")
        
        // Create sample users
        let passwordHash = try Bcrypt.hash("12121212")
        
        let alice = try await findOrCreateUser(
            name: "Alice Johnson",
            email: "alice@example.com",
            passwordHash: passwordHash,
            on: database
        )
        
        let bob = try await findOrCreateUser(
            name: "Bob Smith",
            email: "bob@example.com",
            passwordHash: passwordHash,
            on: database
        )
        
        let charlie = try await findOrCreateUser(
            name: "Charlie Brown",
            email: "charlie@example.com",
            passwordHash: passwordHash,
            on: database
        )
        
        let diana = try await findOrCreateUser(
            name: "Diana Prince",
            email: "diana@example.com",
            passwordHash: passwordHash,
            on: database
        )
        
        // Create activities
        let weekendTrip = try await findOrCreateActivity(
            name: "Weekend Trip to the Beach",
            activityDate: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 7 days ago
            on: database
        )
        
        let dinnerParty = try await findOrCreateActivity(
            name: "Dinner Party",
            activityDate: Date().addingTimeInterval(-3 * 24 * 60 * 60), // 3 days ago
            on: database
        )
        
        let movieNight = try await findOrCreateActivity(
            name: "Movie Night",
            activityDate: Date().addingTimeInterval(-1 * 24 * 60 * 60), // 1 day ago
            on: database
        )
        
        // Add participants to activities
        try await addParticipantIfNotExists(
            activity: weekendTrip,
            user: alice,
            on: database
        )
        try await addParticipantIfNotExists(
            activity: weekendTrip,
            user: bob,
            on: database
        )
        try await addParticipantIfNotExists(
            activity: weekendTrip,
            user: charlie,
            on: database
        )
        
        try await addParticipantIfNotExists(
            activity: dinnerParty,
            user: alice,
            on: database
        )
        try await addParticipantIfNotExists(
            activity: dinnerParty,
            user: bob,
            on: database
        )
        try await addParticipantIfNotExists(
            activity: dinnerParty,
            user: diana,
            on: database
        )
        
        try await addParticipantIfNotExists(
            activity: movieNight,
            user: charlie,
            on: database
        )
        try await addParticipantIfNotExists(
            activity: movieNight,
            user: diana,
            on: database
        )
        
        // Create expenses for weekend trip
        let hotelExpense = try await findOrCreateExpense(
            name: "Hotel Room",
            amountInCents: 20000, // $200.00
            payerID: alice.id!,
            activityID: weekendTrip.id!,
            on: database
        )
        
        let gasExpense = try await findOrCreateExpense(
            name: "Gas",
            amountInCents: 5000, // $50.00
            payerID: bob.id!,
            activityID: weekendTrip.id!,
            on: database
        )
        
        let foodExpense = try await findOrCreateExpense(
            name: "Restaurant",
            amountInCents: 12000, // $120.00
            payerID: charlie.id!,
            activityID: weekendTrip.id!,
            on: database
        )
        
        // Add participants to hotel expense (split equally among 3 people)
        try await addExpenseParticipantIfNotExists(
            expense: hotelExpense,
            user: alice,
            amountOwedInCents: 6667, // $66.67
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: hotelExpense,
            user: bob,
            amountOwedInCents: 6667, // $66.67
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: hotelExpense,
            user: charlie,
            amountOwedInCents: 6666, // $66.66 (rounding)
            on: database
        )
        
        // Add participants to gas expense (split equally among 3 people)
        try await addExpenseParticipantIfNotExists(
            expense: gasExpense,
            user: alice,
            amountOwedInCents: 1667, // $16.67
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: gasExpense,
            user: bob,
            amountOwedInCents: 1667, // $16.67
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: gasExpense,
            user: charlie,
            amountOwedInCents: 1666, // $16.66 (rounding)
            on: database
        )
        
        // Add participants to food expense (split equally among 3 people)
        try await addExpenseParticipantIfNotExists(
            expense: foodExpense,
            user: alice,
            amountOwedInCents: 4000, // $40.00
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: foodExpense,
            user: bob,
            amountOwedInCents: 4000, // $40.00
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: foodExpense,
            user: charlie,
            amountOwedInCents: 4000, // $40.00
            on: database
        )
        
        // Create expenses for dinner party
        let groceriesExpense = try await findOrCreateExpense(
            name: "Groceries",
            amountInCents: 8000, // $80.00
            payerID: alice.id!,
            activityID: dinnerParty.id!,
            on: database
        )
        
        let wineExpense = try await findOrCreateExpense(
            name: "Wine",
            amountInCents: 3000, // $30.00
            payerID: diana.id!,
            activityID: dinnerParty.id!,
            on: database
        )
        
        // Add participants to groceries expense (split equally among 3 people)
        try await addExpenseParticipantIfNotExists(
            expense: groceriesExpense,
            user: alice,
            amountOwedInCents: 2667, // $26.67
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: groceriesExpense,
            user: bob,
            amountOwedInCents: 2667, // $26.67
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: groceriesExpense,
            user: diana,
            amountOwedInCents: 2666, // $26.66 (rounding)
            on: database
        )
        
        // Add participants to wine expense (split equally among 3 people)
        try await addExpenseParticipantIfNotExists(
            expense: wineExpense,
            user: alice,
            amountOwedInCents: 1000, // $10.00
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: wineExpense,
            user: bob,
            amountOwedInCents: 1000, // $10.00
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: wineExpense,
            user: diana,
            amountOwedInCents: 1000, // $10.00
            on: database
        )
        
        // Create expenses for movie night
        let ticketsExpense = try await findOrCreateExpense(
            name: "Movie Tickets",
            amountInCents: 2500, // $25.00
            payerID: charlie.id!,
            activityID: movieNight.id!,
            on: database
        )
        
        let snacksExpense = try await findOrCreateExpense(
            name: "Snacks",
            amountInCents: 1500, // $15.00
            payerID: diana.id!,
            activityID: movieNight.id!,
            on: database
        )
        
        // Add participants to tickets expense (split equally among 2 people)
        try await addExpenseParticipantIfNotExists(
            expense: ticketsExpense,
            user: charlie,
            amountOwedInCents: 1250, // $12.50
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: ticketsExpense,
            user: diana,
            amountOwedInCents: 1250, // $12.50
            on: database
        )
        
        // Add participants to snacks expense (split equally among 2 people)
        try await addExpenseParticipantIfNotExists(
            expense: snacksExpense,
            user: charlie,
            amountOwedInCents: 750, // $7.50
            on: database
        )
        try await addExpenseParticipantIfNotExists(
            expense: snacksExpense,
            user: diana,
            amountOwedInCents: 750, // $7.50
            on: database
        )
        
        // Create some payments
        try await addPaymentIfNotExists(
            expense: hotelExpense,
            debtor: bob,
            amountPaidInCents: 6667, // $66.67
            on: database
        )
        
        try await addPaymentIfNotExists(
            expense: hotelExpense,
            debtor: charlie,
            amountPaidInCents: 6666, // $66.66
            on: database
        )
        
        try await addPaymentIfNotExists(
            expense: gasExpense,
            debtor: alice,
            amountPaidInCents: 1667, // $16.67
            on: database
        )
        
        try await addPaymentIfNotExists(
            expense: wineExpense,
            debtor: alice,
            amountPaidInCents: 1000, // $10.00
            on: database
        )
        
        try await addPaymentIfNotExists(
            expense: wineExpense,
            debtor: bob,
            amountPaidInCents: 1000, // $10.00
            on: database
        )
    }
    
    func revert(on database: any Database) async throws {
        // Delete all seeded data in reverse order
        try await ExpensePayment.query(on: database).delete()
        try await ExpenseParticipant.query(on: database).delete()
        try await Expense.query(on: database).delete()
        try await ActivityParticipant.query(on: database).delete()
        try await Activity.query(on: database).delete()
        try await User.query(on: database).delete()
    }
}

// MARK: - Helper Functions

private func findOrCreateUser(
    name: String,
    email: String,
    passwordHash: String,
    on database: any Database
) async throws -> User {
    if let existing = try await User.query(on: database)
        .filter(\.$email == email)
        .first() {
        return existing
    }
    
    let user = User(
        name: name,
        email: email,
        passwordHash: passwordHash
    )
    try await user.save(on: database)
    return user
}

private func findOrCreateActivity(
    name: String,
    activityDate: Date,
    on database: any Database
) async throws -> Activity {
    if let existing = try await Activity.query(on: database)
        .filter(\.$name == name)
        .first() {
        return existing
    }
    
    let activity = Activity(
        name: name,
        activityDate: activityDate
    )
    try await activity.save(on: database)
    return activity
}

private func addParticipantIfNotExists(
    activity: Activity,
    user: User,
    on database: any Database
) async throws {
    let exists = try await ActivityParticipant.query(on: database)
        .filter(\.$activity.$id == activity.id!)
        .filter(\.$user.$id == user.id!)
        .first() != nil
    
    if exists {
        return
    }
    
    let participant = ActivityParticipant(
        activityID: activity.id!,
        userID: user.id!
    )
    try await participant.save(on: database)
}

private func findOrCreateExpense(
    name: String,
    amountInCents: Int,
    payerID: UUID,
    activityID: UUID,
    on database: any Database
) async throws -> Expense {
    if let existing = try await Expense.query(on: database)
        .filter(\.$name == name)
        .filter(\.$activity.$id == activityID)
        .first() {
        return existing
    }
    
    let expense = Expense(
        name: name,
        amountInCents: amountInCents,
        payerID: payerID,
        activityID: activityID
    )
    try await expense.save(on: database)
    return expense
}

private func addExpenseParticipantIfNotExists(
    expense: Expense,
    user: User,
    amountOwedInCents: Int,
    on database: any Database
) async throws {
    let exists = try await ExpenseParticipant.query(on: database)
        .filter(\.$expense.$id == expense.id!)
        .filter(\.$user.$id == user.id!)
        .first() != nil
    
    if exists {
        return
    }
    
    let participant = ExpenseParticipant(
        expenseID: expense.id!,
        userID: user.id!,
        amountOwedInCents: amountOwedInCents
    )
    try await participant.save(on: database)
}

private func addPaymentIfNotExists(
    expense: Expense,
    debtor: User,
    amountPaidInCents: Int,
    on database: any Database
) async throws {
    let exists = try await ExpensePayment.query(on: database)
        .filter(\.$expense.$id == expense.id!)
        .filter(\.$debtor.$id == debtor.id!)
        .first() != nil
    
    if exists {
        return
    }
    
    let payment = ExpensePayment(
        expenseID: expense.id!,
        debtorID: debtor.id!,
        amountPaidInCents: amountPaidInCents
    )
    try await payment.save(on: database)
}
