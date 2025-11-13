# Part 4 - Balance Controller and Services

## Table of Contents
1. [BalanceService](#1-balanceservice)
2. [CompensationService](#2-compensationservice)
3. [BalanceController](#3-balancecontroller)

---

## 1. BalanceService

This service handles all balance calculations without compensation.

### File: `Sources/App/Services/BalanceService.swift`

```swift
import Vapor
import Fluent

struct BalanceService {
    
    // MARK: - Balance for Single Activity
    func calculateActivityBalance(activityId: UUID, on db: Database) async throws -> ActivityBalanceResponse {
        guard let activity = try await Activity.query(on: db)
            .filter(\.$id == activityId)
            .with(\.$expenses) { expense in
                expense.with(\.$payer)
                expense.with(\.$participants)
            }
            .with(\.$participants)
            .first() else {
            throw Abort(.notFound, reason: "Activity not found")
        }
        
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
                continue  // Skip expenses without a payer
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
    func calculateDetailedBalance(userId: UUID, on db: Database) async throws -> DetailedBalanceResponse {
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
            debts.append(DetailedBalanceResponse.DebtDetail(
                creditorName: expense.payer.name,
                creditorId: expense.payer.id!,
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
```

---

## 2. CompensationService

This service handles the complex global compensation logic across all activities.

### File: `Sources/App/Services/CompensationService.swift`

```swift
import Vapor
import Fluent

struct CompensationService {
    
    // MARK: - Balance Between Two Specific Users (Global Compensation)
    func calculateBalanceBetweenUsers(
        userId1: UUID,
        userId2: UUID,
        on db: Database
    ) async throws -> BalanceBetweenUsersResponse {
        
        // Find all activities where both users are participants
        let user1Activities = try await ActivityParticipant.query(on: db)
            .filter(\.$user.$id == userId1)
            .all()
            .map { $0.$activity.id }
        
        let user2Activities = try await ActivityParticipant.query(on: db)
            .filter(\.$user.$id == userId2)
            .all()
            .map { $0.$activity.id }
        
        let commonActivityIds = Set(user1Activities).intersection(Set(user2Activities))
        
        guard !commonActivityIds.isEmpty else {
            return BalanceBetweenUsersResponse(netBalance: nil, details: [])
        }
        
        // Get user details
        guard let user1 = try await User.find(userId1, on: db),
              let user2 = try await User.find(userId2, on: db) else {
            throw Abort(.notFound, reason: "One or both users not found")
        }
        
        var details: [BalanceBetweenUsersResponse.ActivityDetail] = []
        var netBalance: Int = 0 // Positive = user1 owes user2, Negative = user2 owes user1
        
        for activityId in commonActivityIds {
            guard let activity = try await Activity.query(on: db)
                .filter(\.$id == activityId)
                .with(\.$expenses) { expense in
                    expense.with(\.$payer)
                }
                .first() else {
                continue
            }
            
            var activityBalance: Int = 0
            
            // Check each expense in the activity
            for expense in activity.expenses {
                // Only process expenses with a payer set
                guard let payerId = expense.$payer.id else {
                    continue  // Skip expenses without a payer
                }
                
                // Get expense participants
                let expenseParticipants = try await ExpenseParticipant.query(on: db)
                    .filter(\.$expense.$id == expense.id!)
                    .all()
                
                // Case 1: user1 paid, user2 is debtor
                if payerId == userId1 {
                    if let user2Debt = expenseParticipants.first(where: { $0.$user.id == userId2 }) {
                        activityBalance -= user2Debt.amountOwedInCents // user2 owes user1
                    }
                }
                
                // Case 2: user2 paid, user1 is debtor
                if payerId == userId2 {
                    if let user1Debt = expenseParticipants.first(where: { $0.$user.id == userId1 }) {
                        activityBalance += user1Debt.amountOwedInCents // user1 owes user2
                    }
                }
            }
            
            if activityBalance != 0 {
                let fromUser = activityBalance > 0 ? user1.name : user2.name
                let toUser = activityBalance > 0 ? user2.name : user1.name
                
                details.append(BalanceBetweenUsersResponse.ActivityDetail(
                    activityName: activity.name,
                    activityId: activity.id!,
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
        on db: Database
    ) async throws -> UserGlobalBalanceResponse {
        
        guard let user = try await User.find(userId, on: db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        // Get all activities for this user
        let userActivities = try await ActivityParticipant.query(on: db)
            .filter(\.$user.$id == userId)
            .with(\.$activity) { activity in
                activity.with(\.$expenses) { expense in
                    expense.with(\.$payer)
                }
                activity.with(\.$participants)
            }
            .all()
        
        // Collect all unique users
        var allUserIds = Set<UUID>()
        for activityParticipant in userActivities {
            for participant in activityParticipant.activity.participants {
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
            
            // Determine if this is a debt or credit
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
                    activities: value.activities
                ))
            } else if value.netAmount < 0 {
                // This person owes user
                compensatedCredits.append(UserGlobalBalanceResponse.CompensatedCredit(
                    debtorName: value.user.name,
                    debtorId: value.user.id!,
                    netAmountInCents: abs(value.netAmount),
                    activitiesCount: value.activities.count,
                    activities: value.activities
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

// MARK: - Helper Types
struct ActivityBreakdown: Codable {
    let activityName: String
    let activityId: UUID
    let amountInCents: Int
}
```

---

## 3. BalanceController

### File: `Sources/App/Controllers/BalanceController.swift`

```swift
import Vapor
import Fluent

struct BalanceController: RouteCollection {
    let balanceService = BalanceService()
    let compensationService = CompensationService()
    
    func boot(routes: RoutesBuilder) throws {
        // Routes are registered in routes.swift
    }
    
    // MARK: - Activity Balance (No Global Compensation)
    func activityBalance(req: Request) async throws -> ActivityBalanceResponse {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid activity ID")
        }
        
        // Verify user is participant
        let isParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == activityId)
            .filter(\.$user.$id == user.id!)
            .first() != nil
        
        guard isParticipant else {
            throw Abort(.forbidden, reason: "You must be a participant of this activity")
        }
        
        return try await balanceService.calculateActivityBalance(
            activityId: activityId,
            on: req.db
        )
    }
    
    // MARK: - Balance Between Two Users (Global Compensation)
    func balanceBetweenUsers(req: Request) async throws -> BalanceBetweenUsersResponse {
        let user = try req.auth.require(User.self)
        
        guard let userId1 = req.parameters.get("userId1", as: UUID.self),
              let userId2 = req.parameters.get("userId2", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user IDs")
        }
        
        // User can only check their own balances
        guard userId1 == user.id! || userId2 == user.id! else {
            throw Abort(.forbidden, reason: "You can only check balances involving yourself")
        }
        
        return try await compensationService.calculateBalanceBetweenUsers(
            userId1: userId1,
            userId2: userId2,
            on: req.db
        )
    }
    
    // MARK: - User Global Balance (All Compensations)
    func userGlobalBalance(req: Request) async throws -> UserGlobalBalanceResponse {
        let user = try req.auth.require(User.self)
        
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        // Users can only view their own global balance
        guard userId == user.id! else {
            throw Abort(.forbidden, reason: "You can only view your own balance")
        }
        
        return try await compensationService.calculateUserGlobalBalance(
            userId: userId,
            on: req.db
        )
    }
    
    // MARK: - Detailed Balance (No Compensation)
    func detailedBalance(req: Request) async throws -> DetailedBalanceResponse {
        let user = try req.auth.require(User.self)
        
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        // Users can only view their own detailed balance
        guard userId == user.id! else {
            throw Abort(.forbidden, reason: "You can only view your own balance")
        }
        
        return try await balanceService.calculateDetailedBalance(
            userId: userId,
            on: req.db
        )
    }
}
```

---

## Summary

This part covered the **most complex logic** of the entire API:

1. ✅ **BalanceService**:
   - Calculate balance for a single activity
   - Match debtors with creditors efficiently
   - Detailed balance view without compensation

2. ✅ **CompensationService**:
   - **Global compensation between two users** - The key feature!
   - Calculates net balance across ALL activities
   - Example: If A owes B $50 in Activity 1, but B owes A $30 in Activity 2, final result is A owes B only $20
   - **User global balance** - Shows all compensated debts and credits
   - Handles complex scenarios with multiple activities

3. ✅ **BalanceController**:
   - Four different endpoints for different balance views
   - Authorization checks (users can only see their own data)
   - Integration with both services

**How the compensation works:**

```
User A and User B shared 3 activities:
- Activity 1: B paid $100, A owes $50
- Activity 2: A paid $80, B owes $40
- Activity 3: B paid $60, A owes $30

Without compensation: 
  A owes B: $50 + $30 = $80
  B owes A: $40
  
With global compensation:
  Net: A owes B only $40 ($80 - $40)
```

**Next up: Part 5 - Docker Configuration**

This will cover:
- Dockerfile
- docker-compose.yml for local development
- Multi-stage builds for production