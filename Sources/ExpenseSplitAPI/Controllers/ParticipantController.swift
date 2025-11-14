//
//  ParticipantController.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 14/11/25.
//

import Vapor
import Fluent

struct ParticipantController: RouteCollection {
    
    func boot(routes: any RoutesBuilder) throws {
        // Routes are registered in routes.swift
    }
    
    // MARK: - Add Participants
    func addParticipants(req: Request) async throws -> AddParticipantsResponse {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let addRequest = try req.content.decode(AddParticipantsRequest.self)
        try addRequest.validate(on: req)
        
        guard let activity = try await Activity.find(activityId, on: req.db) else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .activityNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let isParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == activityId)
            .filter(\.$user.$id == user.id!)
            .first() != nil
        
        guard isParticipant else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .activityNotParticipant,
                arguments: [:],
                locale: req.locale
            )
        }
        
        var addedParticipants: [AddParticipantsResponse.ParticipantInfo] = []
        
        for participantId in addRequest.participantsIds {
            guard let participantUser = try await User.find(participantId, on: req.db) else {
                throw LocalizedAbortError(
                    status: .notFound,
                    key: .participantUserNotFound,
                    arguments: [:],
                    locale: req.locale
                )
            }
            
            let alreadyParticipant = try await ActivityParticipant.query(on: req.db)
                .filter(\.$activity.$id == activityId)
                .filter(\.$user.$id == participantId)
                .first() != nil
            
            guard !alreadyParticipant else {
                continue
            }
            
            let activityParticipant = ActivityParticipant(
                activityID: activityId,
                userID: participantId
            )
            
            try await activityParticipant.save(on: req.db)
            
            addedParticipants.append(
                AddParticipantsResponse.ParticipantInfo(
                    userId: participantId,
                    name: participantUser.name,
                    email: participantUser.email,
                    joinedAt: activityParticipant.joinedAt
                )
            )
        }
        
        let message = LocalizedText.string(
            for: addedParticipants.count == 1 ? .participantAddedSingle : .participantAddedMultiple,
            locale: req.locale,
            arguments: addedParticipants.count == 1 ? [:] : ["count": "\(addedParticipants.count)"],
        )
        
        return AddParticipantsResponse(
            acitivityId: activityId,
            addedParticipants: addedParticipants,
            message: message
        )
    }
    
    // MARK: - Remove Participant
    func removeParticipant(req: Request) async throws -> RemoveParticipantResponse {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self),
              let userId = req.parameters.get("userId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard let activity = try await Activity.find(activityId, on: req.db) else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .activityNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let isParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == activityId)
            .filter(\.$user.$id == user.id!)
            .first() != nil
        
        guard isParticipant else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .activityNotParticipant,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard user.id != userId else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .participantCannotRemoveSelf,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard let activityParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == activityId)
            .filter(\.$user.$id == userId)
            .first() else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .participantNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let removedUser = try await User.find(userId, on: req.db)!
        
        try await activityParticipant.delete(on: req.db)
        
        let message = LocalizedText.string(
            for: .participantRemoved,
            locale: req.locale,
            arguments: [:]
        )
        
        return RemoveParticipantResponse(
            activityId: activityId,
            removedUserId: userId,
            removedUserName: removedUser.name,
            message: message
        )
    }
    
    func listParticipants(req: Request) async throws -> ActivityParticipantsResponse {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .generalInvalidRequest,
                arguments: [:],
                locale: req.locale
            )
        }
        
        guard let activity = try await Activity.find(activityId, on: req.db) else {
            throw LocalizedAbortError(
                status: .notFound,
                key: .activityNotFound,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let isParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == activityId)
            .filter(\.$user.$id == user.id!)
            .first() != nil
        
        guard isParticipant else {
            throw LocalizedAbortError(
                status: .forbidden,
                key: .activityNotParticipant,
                arguments: [:],
                locale: req.locale
            )
        }
        
        let activityParticipants = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == activityId)
            .with(\.$user)
            .all()
        
        let participants: [ActivityParticipantsResponse.ParticipantsInfo] = activityParticipants.map { ap in
            ActivityParticipantsResponse.ParticipantsInfo(
                userId: ap.$user.id,
                name: ap.user.name,
                email: ap.user.email,
                joinedAt: ap.joinedAt
            )
        }
        
        return ActivityParticipantsResponse(
            activityId: activityId,
            activityName: activity.name,
            participants: participants
        )
    }
}
