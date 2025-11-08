import Vapor
import VaporToOpenAPI
import SwiftOpenAPI

func routes(_ app: Application) throws {
    // Health
    app.get("health") { _ async -> HTTPStatus in .ok }.excludeFromOpenAPI()
    app.get { _ async -> String in "Expense Split API - Version 1.0" }.excludeFromOpenAPI()
    
    let api = app.grouped("api", "v1")
    
    // Public auth routes
    let authController = AuthController()
    let authRoutes = api.grouped("users")
    
    authRoutes.post("sign-up", use: authController.signUp)
        .openAPI(
            tags: "Users",
            summary: "Register a new user",
            description: "Creates an account and returns a JWT token.",
            body: .type(SignUpRequest.self),
            response: .type(SignUpResponse.self)
        )
    
    authRoutes.post("sign-in", use: authController.signIn)
        .openAPI(
            tags: "Users",
            summary: "Authenticate a user",
            description: "Accepts email/password and returns a JWT token.",
            body: .type(SignInRequest.self),
            response: .type(SignInResponse.self)
        )
    
    // Protected routes (JWT)
    let protected = api
        .grouped(UserAuthenticator(), User.guardMiddleware())
        .groupedOpenAPI(auth: .bearer(id: "BearerAuth", format: "JWT"))
    
    protected.get("users", "me", use: authController.getProfile)
        .openAPI(
            tags: "Users",
            summary: "Get current user profile",
            description: "Returns the authenticated user's profile.",
            response: .type(UserProfileResponse.self)
        )
    
    // OpenAPI
    app.get("openapi.json") { _ in
        app.routes.openAPI(
            info: .init(
                title: "Expense Split API",
                description: "REST API for splitting expenses",
                version: "1.0.0"
            ),
            servers: [.init(url: "http://localhost:8080")]
        )
    }
    .excludeFromOpenAPI()
    
    app.get("docs") { req -> Response in
        req.redirect(to: "/swagger/index.html")
    }
    .excludeFromOpenAPI()
}
