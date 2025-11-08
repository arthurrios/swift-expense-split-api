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
    }
}
