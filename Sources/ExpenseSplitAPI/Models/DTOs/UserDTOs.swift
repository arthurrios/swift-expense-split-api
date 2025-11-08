//
//  UserDTOs.swift
//  ExpenseSplitAPI
//
//  Created by Arthur Rios on 07/11/25.
//

import Vapor

// MARK: - Sign Up
struct SignUpRequest: Content {
    let name: String
    let email: String
    let password: String
    
    func validate(on req: Request) throws {
        if name.count < 2 {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .signupNameMinLength,
                arguments: ["min": "2"],
                locale: req.locale
            )
        }
        
        if email.isEmpty {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .signinEmailRequired,
                arguments: [:],
                locale: req.locale
            )
        }
        
        if !Validators.isValidEmail(email) {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .signupEmailInvalid,
                arguments: [:],
                locale: req.locale
            )
        }
        
        if password.count < 8 {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .signupPasswordMinLength,
                arguments: ["min": "8"],
                locale: req.locale
            )
        }
    }
}

struct SignUpResponse: Content {
    let id: UUID
    let name: String
    let email: String
    let token: String
}

struct SignInRequest: Content {
    let email: String
    let password: String
    
    func validate(on req: Request) throws {
        if email.isEmpty {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .signinEmailRequired,
                arguments: [:],
                locale: req.locale
            )
        }
        
        if !Validators.isValidEmail(email) {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .signupEmailInvalid,
                arguments: [:],
                locale: req.locale
            )
        }
        
        if password.isEmpty {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .signinPasswordRequired,
                arguments: [:],
                locale: req.locale
            )
        }
        
        if password.count < 8 {
            throw LocalizedAbortError(
                status: .badRequest,
                key: .signupPasswordMinLength,
                arguments: ["min": "8"],
                locale: req.locale
            )
        }
    }
}

struct SignInResponse: Content {
    let id: UUID
    let name: String
    let email: String
    let token: String
}

struct UserProfileResponse: Content {
    let id: UUID
    let name: String
    let email: String
    let createdAt: Date?
    
    init(from user: User) {
        self.id = user.id!
        self.name = user.name
        self.email = user.email
        self.createdAt = user.createdAt
    }
}
