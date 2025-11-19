//
//  BalanceService.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 14/11/25.
//

import Vapor
import Fluent

struct BalanceService {
    
    // MARK: - Balance for Single Activity
    func calculateActivityBalance(activityId: UUID, on db: any Database) async throws -> ActivityBalanceResponse {
        guard let activity = try await Activity.query(on: db)
            .filter(\.$id == activityId)
            .with(\.$expenses)
            .with(\.$participants)
            .first() else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .activityNotFound,
                arguments: [:],
                locale: Locale(identifier: "en")
            )
        }
        
        // Load expense relationships
        try await activity.$expenses.load(on: db)
        for expense in activity.expenses {
            try await expense.$payer.load(on: db)
        }
        try await activity.$participants.load(on: db)
        
        // Calculate balances for each user
        var userBalances: [UUID: Int] = [:]
        
        // Initialize all participants with 0
        for participant in activity.participants {
            userBalances[participant.id!] = 0
        }
        
        // Process each expense
        for expense in activity.expenses {
            // Only process expenses with a payer set
            guard let payerId = expense.$payer.id else {
                continue
            }
            
            let totalAmount = expense.amountInCents
            
            // Payer gets credited
            userBalances[payerId, default: 0] += totalAmount
            
            // Get debt distribution
            let expenseParticipants = try await ExpenseParticipant.query(on: db)
                .filter(\.$expense.$id == expense.id!)
                .all()
            
            // Each debtor gets debited
            for ep in expenseParticipants {
                let debtorId = ep.$user.id
                userBalances[debtorId, default: 0] -= ep.amountOwedInCents
            }
        }
        
        // Create transfer list
        var transfers: [ActivityBalanceResponse.Transfer] = []
        
        // Separate debtors and creditors
        var debtors: [(userId: UUID, amount: Int)] = []
        var creditors: [(userId: UUID, amount: Int)] = []
        
        for (userId, balance) in userBalances {
            if balance < 0 {
                debtors.append((userId, -balance))
            } else if balance > 0 {
                creditors.append((userId, balance))
            }
        }
        
        // Sort for consistent results
        debtors.sort { $0.amount > $1.amount }
        creditors.sort { $0.amount > $1.amount }
        
        // Match debtors with creditors
        var debtorIndex = 0
        var creditorIndex = 0
        
        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            var debtor = debtors[debtorIndex]
            var creditor = creditors[creditorIndex]
            
            let transferAmount = min(debtor.amount, creditor.amount)
            
            // Get user details
            let debtorUser = activity.participants.first { $0.id == debtor.userId }!
            let creditorUser = activity.participants.first { $0.id == creditor.userId }!
            
            transfers.append(ActivityBalanceResponse.Transfer(
                from: ActivityBalanceResponse.UserInfo(
                    userId: debtor.userId,
                    name: debtorUser.name
                ),
                to: ActivityBalanceResponse.UserInfo(
                    userId: creditor.userId,
                    name: creditorUser.name
                ),
                amountInCents: transferAmount
            ))
            
            // Update remaining amounts
            debtor.amount -= transferAmount
            creditor.amount -= transferAmount
            
            if debtor.amount == 0 {
                debtorIndex += 1
            } else {
                debtors[debtorIndex] = debtor
            }
            
            if creditor.amount == 0 {
                creditorIndex += 1
            } else {
                creditors[creditorIndex] = creditor
            }
        }
        
        return ActivityBalanceResponse(
            activityId: activityId,
            activityName: activity.name,
            transfers: transfers
        )
    }
    
    // MARK: - Detailed Balance for User (All Activities, No Compensation)
    func calculateDetailedBalance(userId: UUID, on db: any Database) async throws -> DetailedBalanceResponse {
        // Get all expenses where user is payer
        let expensesAsPayer = try await Expense.query(on: db)
            .filter(\.$payer.$id == userId)
            .with(\.$activity)
            .all()
        
        // Get all expense participants where user is debtor
        let expenseParticipants = try await ExpenseParticipant.query(on: db)
            .filter(\.$user.$id == userId)
            .with(\.$expense) { expense in
                expense.with(\.$payer)
                expense.with(\.$activity)
            }
            .all()
        
        var credits: [DetailedBalanceResponse.CreditDetail] = []
        var debts: [DetailedBalanceResponse.DebtDetail] = []
        
        // Process credits (user is payer, others owe them)
        for expense in expensesAsPayer {
            try await expense.$activity.load(on: db)
            let debtors = try await ExpenseParticipant.query(on: db)
                .filter(\.$expense.$id == expense.id!)
                .with(\.$user)
                .all()
            
            for debtor in debtors {
                credits.append(DetailedBalanceResponse.CreditDetail(
                    debtorName: debtor.user.name,
                    debtorId: debtor.user.id!,
                    amountInCents: debtor.amountOwedInCents,
                    activityName: expense.activity.name,
                    activityId: expense.activity.id!,
                    expenseName: expense.name,
                    expenseId: expense.id!
                ))
            }
        }
        
        // Process debts (user is debtor, they owe payer)
        for ep in expenseParticipants {
            let expense = ep.expense
            try await expense.$payer.load(on: db)
            try await expense.$activity.load(on: db)
            
            guard let payer = expense.payer else {
                continue
            }
            
            debts.append(DetailedBalanceResponse.DebtDetail(
                creditorName: payer.name,
                creditorId: payer.id!,
                amountInCents: ep.amountOwedInCents,
                activityName: expense.activity.name,
                activityId: expense.activity.id!,
                expenseName: expense.name,
                expenseId: expense.id!
            ))
        }
        
        let totalCredit = credits.reduce(0) { $0 + $1.amountInCents }
        let totalDebt = debts.reduce(0) { $0 + $1.amountInCents }
        
        return DetailedBalanceResponse(
            totalOwedToUserInCents: totalCredit,
            totalUserOwesInCents: totalDebt,
            debts: debts,
            credits: credits
        )
    }
}
