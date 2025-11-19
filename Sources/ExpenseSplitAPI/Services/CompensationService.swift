//
//  CompensationService.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 19/11/25.
//

import Vapor
import Fluent

struct CompensationService {
    
    // MARK: - Balance Between Two Specific Users (Global Compensation)
    func calculateBalanceBetweenUsers(
        userId1: UUID,
        userId2: UUID,
        on db: any Database
    ) async throws -> BalanceBetweenUsersResponse {
        
        // Find all activities where both users are participants
        let user1Activities = try await ActivityParticipant.query(on: db)
            .filter(\.$user.$id == userId1)
            .all()
        
        let user2Activities = try await ActivityParticipant.query(on: db)
            .filter(\.$user.$id == userId2)
            .all()
        
        let user1ActivityIds = Set(user1Activities.map { $0.$activity.id })
        let user2ActivityIds = Set(user2Activities.map { $0.$activity.id })
        let commomActivityIds = user1ActivityIds.intersection(user2ActivityIds)
        
        guard !commomActivityIds.isEmpty else {
            return BalanceBetweenUsersResponse(netBalance: nil, details: [])
        }
        
        // Get user details
        guard let user1 = try await User.find(userId1, on: db),
              let user2 = try await User.find(userId2, on: db) else {
            throw Abort(.notFound, reason: "One or both users not found")
        }
        
        var details: [BalanceBetweenUsersResponse.ActivityDetail] = []
        var netBalance: Int = 0 // Positive = user1 owes user2, Negative = user2 owes user1
        
        for activityId in commomActivityIds {
            // Load activity with expenses and payers
            guard let activity = try await Activity.find(activityId, on: db) else {
                continue
            }
            
            // Load expenses
            try await activity.$expenses.load(on: db)
            
            // Load payer for each expense
            for expense in activity.expenses {
                try await expense.$payer.load(on: db)
            }
            
            var activityBalance: Int = 0
            
            // Check each expense in activity
            for expense in activity.expenses {
                // Only process expenses with a payer set
                guard let payerId = expense.$payer.id else {
                    continue
                }
                
                // Get expense participants
                let expenseParticipants = try await ExpenseParticipant.query(on: db)
                    .filter(\.$expense.$id == expense.id!)
                    .all()
                
                // Case 1: user1 paid, user2 is debtor
                if payerId == userId1 {
                    if let user2Debt = expenseParticipants.first(where: { $0.$user.id == userId2 }) {
                        activityBalance -= user2Debt.amountOwedInCents
                    }
                }
                
                // Case 2: user2 paid, user1 is debtor
                if payerId == userId2 {
                    if let user1Debt = expenseParticipants.first(where: { $0.$user.id == userId1 }) {
                        activityBalance += user1Debt.amountOwedInCents
                    }
                }
            }
            
            if activityBalance != 0 {
                let fromUser = activityBalance > 0 ? user1.name : user2.name
                let toUser = activityBalance > 0 ? user2.name : user1.name
                
                details.append(BalanceBetweenUsersResponse.ActivityDetail(
                    activityId: activity.id!,
                    activityName: activity.name,
                    fromUser: fromUser,
                    toUser: toUser,
                    amountInCents: abs(activityBalance)
                ))
                
                netBalance += activityBalance
            }
        }
        
        // Create net balance result
        let finalNetBalance: BalanceBetweenUsersResponse.NetBalance?
        
        if netBalance != 0 {
            let debtor = netBalance > 0 ? user1 : user2
            let creditor = netBalance > 0 ? user2 : user1
            
            finalNetBalance = BalanceBetweenUsersResponse.NetBalance(
                debtor: BalanceBetweenUsersResponse.UserInfo(
                    userId: debtor.id!,
                    name: debtor.name
                ),
                creditor: BalanceBetweenUsersResponse.UserInfo(
                    userId: creditor.id!,
                    name: creditor.name
                ),
                amountInCents: abs(netBalance)
            )
        } else {
            finalNetBalance = nil
        }
        
        return BalanceBetweenUsersResponse(
            netBalance: finalNetBalance,
            details: details
        )
    }
    
    // MARK: - Global Balance for User (All Compensations)
    func calculateUserGlobalBalance(
        userId: UUID,
        on db: any Database
    ) async throws -> UserGlobalBalanceResponse {
        guard let user = try await User.find(userId, on: db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        // Get all activities for this user
        let userActivities = try await ActivityParticipant.query(on: db)
            .filter(\.$user.$id == userId)
            .all()
        
        // Collect all unique users from all activities
        var allUserIds = Set<UUID>()
        
        for activityParticipant in userActivities {
            let activityId = activityParticipant.$activity.id
            
            // Load activity and its participants
            guard let activity = try await Activity.find(activityId, on: db) else {
                continue
            }
            
            try await activity.$participants.load(on: db)
            
            for participant in activity.participants {
                if participant.id != userId {
                    allUserIds.insert(participant.id!)
                }
            }
        }
        
        // Calculate balance with each user
        var userBalances: [UUID: (user: User, netAmount: Int, activities: [ActivityBreakdown])] = [:]
        
        for otherUserId in allUserIds {
            let balanceBetween = try await calculateBalanceBetweenUsers(
                userId1: userId,
                userId2: otherUserId,
                on: db
            )
            
            guard let netBalance = balanceBetween.netBalance else {
                continue // No balance between these users
            }
            
            guard let otherUser = try await User.find(otherUserId, on: db) else {
                continue
            }
            
            let activities = balanceBetween.details.map { detail in
                var amount = detail.amountInCents
                if detail.fromUser != user.name {
                    amount = -amount
                }
                
                return ActivityBreakdown(
                    activityName: detail.activityName,
                    activityId: detail.activityId,
                    amountInCents: amount
                )
            }
            
            // Determine if this is debt or credit
            let netAmount: Int
            if netBalance.debtor.userId == userId {
                netAmount = netBalance.amountInCents // User owes money
            } else {
                netAmount = -netBalance.amountInCents // User is owed money
            }
            
            userBalances[otherUserId] = (
                user: otherUser,
                netAmount: netAmount,
                activities: activities
            )
        }
        
        // Separate into debts and credits
        var compensatedDebts: [UserGlobalBalanceResponse.CompensatedDebt] = []
        var compensatedCredits: [UserGlobalBalanceResponse.CompensatedCredit] = []
        var globalNetBalance: Int = 0
        
        for (_, value) in userBalances {
            globalNetBalance += value.netAmount
            
            if value.netAmount > 0 {
                // User owes this person
                compensatedDebts.append(UserGlobalBalanceResponse.CompensatedDebt(
                    creditorName: value.user.name,
                    creditorId: value.user.id!,
                    netAmountInCents: value.netAmount,
                    activitiesCount: value.activities.count,
                    activities: value.activities.map {
                        UserGlobalBalanceResponse.ActivityBreakdown(
                            activityId: $0.activityId,
                            activityName: $0.activityName,
                            amountInCents: $0.amountInCents
                        )
                    }
                ))
            } else if value.netAmount < 0 {
                // This person owes user
                compensatedCredits.append(UserGlobalBalanceResponse.CompensatedCredit(
                    debtorName: value.user.name,
                    debtorId: value.user.id!,
                    netAmountInCents: abs(value.netAmount),
                    activitiesCount: value.activities.count,
                    activities: value.activities.map {
                        UserGlobalBalanceResponse.ActivityBreakdown(
                            activityId: $0.activityId,
                            activityName: $0.activityName,
                            amountInCents: $0.amountInCents
                        )
                    }
                ))
            }
        }
        
        // Sort by amount (highest first)
        compensatedDebts.sort { $0.netAmountInCents > $1.netAmountInCents }
        compensatedCredits.sort { $0.netAmountInCents > $1.netAmountInCents }
        
        return UserGlobalBalanceResponse(
            globalNetBalanceInCents: globalNetBalance,
            compensatedDebts: compensatedDebts,
            compensatedCredits: compensatedCredits
        )
    }
}
