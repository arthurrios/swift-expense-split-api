import Vapor
import VaporToOpenAPI
import SwiftOpenAPI

func routes(_ app: Application) throws {
    // Health
    app.get("health") { _ async -> HTTPStatus in .ok }.excludeFromOpenAPI()
    app.get { _ async -> String in "Expense Split API - Version 1.0" }.excludeFromOpenAPI()
    
    // Controllers
    let authController = AuthController()
    let activityController = ActivityController()
    let expenseController = ExpenseController()
    
    // Base groups
    let api = app.grouped("api", "v1")
    
    // Public routes - Users
    let users = api.grouped("users").groupedOpenAPI(tags: TagObject(name: "Users"))
    
    users.post("sign-up", use: authController.signUp)
        .openAPI(
            tags: "Users",
            summary: "Register a new user",
            description: "Creates an account and returns a JWT token.",
            body: .type(SignUpRequest.self),
            response: .type(SignUpResponse.self)
        )
    
    users.post("sign-in", use: authController.signIn)
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
    
    // Protected - Users
    protected.get("users", "me", use: authController.getProfile)
        .openAPI(
            tags: "Users",
            summary: "Get current user profile",
            description: "Returns the authenticated user's profile.",
            response: .type(UserProfileResponse.self)
        )
    
    protected.get("users", use: authController.listUsers)
        .openAPI(
            tags: "Users",
            summary: "List all users",
            description: "Returns all users. Optionally filter by activityId query parameter to identify which users are participants in a specific activity.",
            response: .type(UserListResponse.self)
        )
    
    // Protected - Activities
    protected.post("activities", use: activityController.create)
        .openAPI(
            tags: "Activities",
            summary: "Create a new activity",
            description: "Creates a new activity and adds the creator as a participant.",
            body: .type(CreateActivityRequest.self),
            response: .type(CreateActivityResponse.self)
        )
    
    protected.put("activities", ":activityId", use: activityController.update)
        .openAPI(
            tags: "Activities",
            summary: "Update an activity",
            description: "Updates an activity. Only participants can update.",
            body: .type(UpdateActivityRequest.self),
            response: .type(CreateActivityResponse.self)
        )
    
    protected.get("users", ":userId", "activities", use: activityController.list)
        .openAPI(
            tags: "Activities",
            summary: "List user's activities",
            description: "Returns all activities for a user. Users can only view their own activities.",
            response: .type(ActivityListResponse.self)
        )
    
    protected.get("activities", ":activityId", use: activityController.detail)
        .openAPI(
            tags: "Activities",
            summary: "Get activity details",
            description: "Returns detailed information about an activity, including participants and expenses.",
            response: .type(ActivityDetailResponse.self)
        )
    
    protected.delete("activities", ":activityId", use: activityController.delete)
        .openAPI(
            tags: "Activities",
            summary: "Delete an activity",
            description: "Deletes an activity and all related expenses, participants, and payments. Only participants can delete an activity.",
            response: .type(HTTPStatus.self)
        )
    
    // Protected - Expenses
    protected.post("activities", ":activityId", "expenses", use: expenseController.create)
        .openAPI(
            tags: "Expenses",
            summary: "Create a new expense",
            description: "Creates a new expense for an activity. Payer is optional and can be set later. Participants are required and will split the expense equally.",
            body: .type(CreateExpenseRequest.self),
            response: .type(CreateExpenseResponse.self)
        )
    
    protected.get("activities", ":activityId", "expenses", use: expenseController.list)
        .openAPI(
            tags: "Expenses",
            summary: "List expenses for an activity",
            description: "Returns all expenses for a specific activity. Only activity participants can view expenses.",
            response: .type(ExpenseListResponse.self)
        )
    
    protected.get("expenses", ":expenseId", use: expenseController.detail)
        .openAPI(
            tags: "Expenses",
            summary: "Get expense details",
            description: "Returns detailed information about an expense, including participants, payments, and remaining debts.",
            response: .type(ExpenseDetailResponse.self)
        )
    
    protected.put("expenses", ":expenseId", use: expenseController.update)
        .openAPI(
            tags: "Expenses",
            summary: "Update an expense",
            description: "Updates an expense. Only activity participants can update. All fields are optional. If participants are updated, existing participants are replaced. If amount is updated, participant amounts are recalculated.",
            body: .type(UpdateExpenseRequest.self),
            response: .type(CreateExpenseResponse.self)
        )
    
    protected.put("expenses", ":expenseId", "payer", use: expenseController.setPayer)
        .openAPI(
            tags: "Expenses",
            summary: "Set or update expense payer",
            description: "Sets or updates the payer for an expense. The payer must be a participant of the activity.",
            body: .type(SetExpensePayerRequest.self),
            response: .type(SetExpensePayerResponse.self)
        )
    
    protected.post("expenses", ":expenseId", "payments", use: expenseController.markPayment)
        .openAPI(
            tags: "Expenses",
            summary: "Mark a payment for an expense",
            description: "Records a payment made by a debtor. The authenticated user must be a participant and debtor of the expense. Payment amount cannot exceed remaining debt.",
            body: .type(MarkPaymentRequest.self),
            response: .type(MarkPaymentResponse.self)
        )
    
    protected.delete("expenses", ":expenseId", use: expenseController.delete)
        .openAPI(
            tags: "Expenses",
            summary: "Delete an expense",
            description: "Deletes an expense and all related participants and payments. Only activity participants can delete expenses.",
            response: .type(HTTPStatus.self)
        )
    
    // OpenAPI
    app.get("openapi.json") { _ in
        app.routes.openAPI(
            info: .init(
                title: "Expense Split API",
                description: "REST API for splitting expenses",
                version: "1.0.0"
            ),
            servers: [.init(url: "/api/v1")],
            map: { route in
                guard
                    route.path.count >= 2,
                    route.path[0] == .constant("api"),
                    route.path[1] == .constant("v1")
                else {
                    return route
                }
                route.path = Array(route.path.dropFirst(2))
                return route
            }
        )
    }
    .excludeFromOpenAPI()
    
    app.get("docs") { req -> Response in
        req.redirect(to: "/swagger/index.html")
    }
    .excludeFromOpenAPI()
}
