//
//  BalanceDTOs.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 14/11/25.
//

import Vapor

// MARK: - Activity Balance (whithout global compensation)
struct ActivityBalanceResponse: Content {
    let activityId: UUID
    let activityName: String
    let transfers: [Transfer]
    
    struct Transfer: Content {
        let from: UserInfo
        let to: UserInfo
        let amountInCents: Int
    }
    
    struct UserInfo: Content {
        let userId: UUID
        let name: String
    }
}

// MARK: - Balance Between Two Users (global compensation)
struct BalanceBetweenUsersResponse: Content {
    let netBalance: NetBalance?
    let details: [ActivityDetail]
    
    struct NetBalance: Content {
        let debtor: UserInfo
        let creditor: UserInfo
        let amountInCents: Int
    }
    
    struct ActivityDetail: Content {
        let activityId: UUID
        let activityName: String
        let fromUser: String
        let toUser: String
        let amountInCents: Int
    }
    
    struct UserInfo: Content {
        let userId: UUID
        let name: String
    }
}

// MARK: User Global Balance (all compensations)
struct UserGlobalBalanceResponse: Content {
    let globalNetBalanceInCents: Int
    let compensatedDebts: [CompensatedDebt]
    let compensatedCredits: [CompensatedCredit]
    
    struct CompensatedDebt: Content {
        let creditorName: String
        let creditorId: UUID
        let netAmountInCents: Int
        let activitiesCount: Int
        let activities: [ActivityBreakdown]
    }
    
    struct CompensatedCredit: Content {
        let debtorName: String
        let debtorId: UUID
        let netAmountInCents: Int
        let activitiesCount: Int
        let activities: [ActivityBreakdown]
    }
    
    struct ActivityBreakdown: Content {
        let activityId: UUID
        let activityName: String
        let amountInCents: Int
    }
}

// MARK: - Detailed Balance (without compensation)
struct DetailedBalanceResponse: Content {
    let totalOwedToUserInCents: Int
    let totalUserOwesInCents: Int
    let debts: [DebtDetail]
    let credits: [CreditDetail]
    
    struct DebtDetail: Content {
        let creditorName: String
        let creditorId: UUID
        let amountInCents: Int
        let activityName: String
        let activityId: UUID
        let expenseName: String
        let expenseId: UUID
    }
    
    struct CreditDetail: Content {
        let debtorName: String
        let debtorId: UUID
        let amountInCents: Int
        let activityName: String
        let activityId: UUID
        let expenseName: String
        let expenseId: UUID
    }
}

// MARK: - Helper Type (user by CompensationService)
struct ActivityBreakdown: Codable {
    let activityName: String
    let activityId: UUID
    let amountInCents: Int
}
