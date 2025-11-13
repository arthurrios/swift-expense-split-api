//
//  ActivityDTOs.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 12/11/25.
//

import Vapor

// MARK: - Create Activity
struct CreateActivityRequest: Content {
    let title: String
    let activityDate: Date
    
    func validate(on req: Request) throws {
        if title.count < 3 {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .activityTitleMinLength,
                arguments: ["min": "3"],
                locale: req.locale
            )
        }
    }
}

struct CreateActivityResponse: Content {
    let id: UUID
    let name: String
    let activityDate: Date
    let createdAt: Date?
}

// MARK: - Update Activity
struct UpdateActivityRequest: Content {
    let newTitle: String?
    let newActivityDate: Date?
    
    func validate(on req: Request) throws {
        if let title = newTitle, title.count < 3 {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .activityTitleMinLength,
                arguments: ["min": "3"],
                locale: req.locale
            )
        }
    }
}

// MARK: - List Activities
struct ActivityListItem: Content {
    let id: UUID
    let name: String
    let totalAmountInCents: Int
    let activityDate: Date
    let participantsAmount: Int
    let expensesAmount: Int
}

struct ActivityListResponse: Content {
    let activities: [ActivityListItem]
}

// MARK: Activity Detail
struct ActivityDetailResponse: Content {
    let id: UUID
    let name: String
    let activityDate: Date
    let participants: [ParticipantInfo]
    let expenses: [ExpenseInfo]
    let totalAmountInCents: Int
    
    struct ParticipantInfo: Content {
        let id: UUID
        let name: String
        let email: String
    }
    
    struct ExpenseInfo: Content {
        let id: UUID
        let name: String
        let amountInCents: Int
        let payerName: String?
        let payerId: UUID?
        let participantsCount: Int
    }
}
