//
//  ParticipantDTOs.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 14/11/25.
//

import Vapor

// MARK: - Add Participants
struct AddParticipantsRequest: Content {
    let participantsIds: [UUID]
    
    func validate(on req: Request) throws {
        if participantsIds.isEmpty {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .participantEmpty,
                arguments: [:],
                locale: req.locale
            )
        }
        
        if Set(participantsIds).count != participantsIds.count {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .participantDuplicate,
                arguments: [:],
                locale: req.locale
            )
        }
    }
}

struct AddParticipantsResponse: Content {
    let acitivityId: UUID
    let addedParticipants: [ParticipantInfo]
    let message: String
    
    struct ParticipantInfo: Content {
        let userId: UUID
        let name: String
        let email: String
        let joinedAt: Date?
    }
}

// MARK: - Remove Participant
struct RemoveParticipantResponse: Content {
    let activityId: UUID
    let removedUserId: UUID
    let removedUserName: String
    let message: String
}

// MARK: - List Participants (for activity)
struct ActivityParticipantsResponse: Content {
    let activityId: UUID
    let activityName: String
    let participants: [ParticipantsInfo]
    
    struct ParticipantsInfo: Content {
        let userId: UUID
        let name: String
        let email: String
        let joinedAt: Date?
    }
}
