# Part 3 - Controllers Implementation

## Table of Contents
1. [AuthController](#1-authcontroller)
2. [ActivityController](#2-activitycontroller)
3. [ExpenseController](#3-expensecontroller)
4. [ParticipantController](#4-participantcontroller)

---

## 1. AuthController

### File: `Sources/App/Controllers/AuthController.swift`

```swift
import Vapor
import Fluent
import JWT

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Routes are registered in routes.swift
    }
    
    // MARK: - Sign Up
    func signUp(req: Request) async throws -> SignUpResponse {
        let signUpRequest = try req.content.decode(SignUpRequest.self)
        try signUpRequest.validate()
        
        // Check if email already exists
        let existingUser = try await User.query(on: req.db)
            .filter(\.$email == signUpRequest.email.lowercased())
            .first()
        
        guard existingUser == nil else {
            throw Abort(.conflict, reason: "Email already registered")
        }
        
        // Hash password
        let passwordHash = try Bcrypt.hash(signUpRequest.password)
        
        // Create user
        let user = User(
            name: signUpRequest.name,
            email: signUpRequest.email.lowercased(),
            passwordHash: passwordHash
        )
        
        try await user.save(on: req.db)
        
        // Generate JWT token
        let token = try generateToken(for: user, on: req)
        
        return SignUpResponse(
            id: user.id!,
            name: user.name,
            email: user.email,
            token: token
        )
    }
    
    // MARK: - Sign In
    func signIn(req: Request) async throws -> SignInResponse {
        let signInRequest = try req.content.decode(SignInRequest.self)
        try signInRequest.validate()
        
        // Find user by email
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == signInRequest.email.lowercased())
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid email or password")
        }
        
        // Verify password
        let isPasswordValid = try Bcrypt.verify(signInRequest.password, created: user.passwordHash)
        guard isPasswordValid else {
            throw Abort(.unauthorized, reason: "Invalid email or password")
        }
        
        // Generate JWT token
        let token = try generateToken(for: user, on: req)
        
        return SignInResponse(
            id: user.id!,
            name: user.name,
            email: user.email,
            token: token
        )
    }
    
    // MARK: - Get Profile
    func getProfile(req: Request) async throws -> UserProfileResponse {
        let user = try req.auth.require(User.self)
        return UserProfileResponse(from: user)
    }
    
    // MARK: - Helper: Generate JWT Token
    private func generateToken(for user: User, on req: Request) throws -> String {
        let payload = UserPayload(
            userId: user.id!,
            email: user.email,
            exp: .init(value: Date().addingTimeInterval(60 * 60 * 24 * 30)) // 30 days
        )
        return try req.jwt.sign(payload)
    }
}
```

---

## 2. ActivityController

### File: `Sources/App/Controllers/ActivityController.swift`

```swift
import Vapor
import Fluent

struct ActivityController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Routes are registered in routes.swift
    }
    
    // MARK: - Create Activity
    func create(req: Request) async throws -> CreateActivityResponse {
        let user = try req.auth.require(User.self)
        let createRequest = try req.content.decode(CreateActivityRequest.self)
        try createRequest.validate()
        
        let activity = Activity(
            name: createRequest.title,
            activityDate: createRequest.activityDate
        )
        
        try await activity.save(on: req.db)
        
        // Add creator as participant
        let participant = ActivityParticipant(
            activityID: activity.id!,
            userID: user.id!
        )
        try await participant.save(on: req.db)
        
        return CreateActivityResponse(
            id: activity.id!,
            name: activity.name,
            activityDate: activity.activityDate,
            createdAt: activity.createdAt
        )
    }
    
    // MARK: - Update Activity
    func update(req: Request) async throws -> Activity {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid activity ID")
        }
        
        let updateRequest = try req.content.decode(UpdateActivityRequest.self)
        try updateRequest.validate()
        
        guard let activity = try await Activity.find(activityId, on: req.db) else {
            throw Abort(.notFound, reason: "Activity not found")
        }
        
        // Verify user is participant
        let isParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == activityId)
            .filter(\.$user.$id == user.id!)
            .first() != nil
        
        guard isParticipant else {
            throw Abort(.forbidden, reason: "You are not a participant of this activity")
        }
        
        // Update fields
        if let newTitle = updateRequest.newTitle {
            activity.name = newTitle
        }
        
        if let newDate = updateRequest.newActivityDate {
            activity.activityDate = newDate
        }
        
        try await activity.save(on: req.db)
        return activity
    }
    
    // MARK: - List Activities
    func list(req: Request) async throws -> ActivityListResponse {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        let authenticatedUser = try req.auth.require(User.self)
        
        // Users can only view their own activities
        guard authenticatedUser.id == userId else {
            throw Abort(.forbidden, reason: "You can only view your own activities")
        }
        
        // Get all activities for this user
        let activityParticipants = try await ActivityParticipant.query(on: req.db)
            .filter(\.$user.$id == userId)
            .with(\.$activity) { activity in
                activity.with(\.$expenses) { expense in
                    expense.with(\.$participants)
                }
                activity.with(\.$participants)
            }
            .all()
        
        let activities = activityParticipants.map { $0.activity }
        
        let activityItems: [ActivityListItem] = activities.map { activity in
            let totalAmount = activity.expenses.reduce(0) { $0 + $1.amountInCents }
            let participantsCount = activity.participants.count
            let expensesCount = activity.expenses.count
            
            return ActivityListItem(
                id: activity.id!,
                name: activity.name,
                totalAmountInCents: totalAmount,
                activityDate: activity.activityDate,
                participantsAmount: participantsCount,
                expensesAmount: expensesCount
            )
        }
        
        return ActivityListResponse(activities: activityItems)
    }
    
    // MARK: - Activity Detail
    func detail(req: Request) async throws -> ActivityDetailResponse {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid activity ID")
        }
        
        guard let activity = try await Activity.query(on: req.db)
            .filter(\.$id == activityId)
            .with(\.$participants)
            .with(\.$expenses) { expense in
                expense.with(\.$payer)
                expense.with(\.$participants)
            }
            .first() else {
            throw Abort(.notFound, reason: "Activity not found")
        }
        
        // Verify user is participant
        let isParticipant = activity.participants.contains { $0.id == user.id }
        guard isParticipant else {
            throw Abort(.forbidden, reason: "You are not a participant of this activity")
        }
        
        let participants = activity.participants.map { participant in
            ActivityDetailResponse.ParticipantInfo(
                id: participant.id!,
                name: participant.name,
                email: participant.email
            )
        }
        
        let expenses = activity.expenses.map { expense in
            ActivityDetailResponse.ExpenseInfo(
                id: expense.id!,
                name: expense.name,
                amountInCents: expense.amountInCents,
                payerName: expense.payer.name,
                payerId: expense.payer.id!,
                participantsCount: expense.participants.count
            )
        }
        
        let totalAmount = activity.expenses.reduce(0) { $0 + $1.amountInCents }
        
        return ActivityDetailResponse(
            id: activity.id!,
            name: activity.name,
            activityDate: activity.activityDate,
            participants: participants,
            expenses: expenses,
            totalAmountInCents: totalAmount
        )
    }
    
    // MARK: - Activity Summary
    func summary(req: Request) async throws -> ActivitySummaryResponse {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        let authenticatedUser = try req.auth.require(User.self)
        
        // Users can only view their own summary
        guard authenticatedUser.id == userId else {
            throw Abort(.forbidden, reason: "You can only view your own summary")
        }
        
        // Get all activities for this user
        let activityParticipants = try await ActivityParticipant.query(on: req.db)
            .filter(\.$user.$id == userId)
            .with(\.$activity) { activity in
                activity.with(\.$expenses) { expense in
                    expense.with(\.$participants)
                    expense.with(\.$payments)
                }
                activity.with(\.$participants)
            }
            .all()
        
        let activities = activityParticipants.map { $0.activity }
        
        // Get all expense participants for this user
        let expenseParticipants = try await ExpenseParticipant.query(on: req.db)
            .filter(\.$user.$id == userId)
            .with(\.$expense) { expense in
                expense.with(\.$payments)
            }
            .all()
        
        var amountPaid = 0
        var amountPendent = 0
        var totalExpenses = 0
        var expensesCount = 0
        var participantsSet = Set<UUID>()
        
        for expenseParticipant in expenseParticipants {
            let expense = expenseParticipant.expense
            let amountOwed = expenseParticipant.amountOwedInCents
            
            // Calculate how much has been paid
            let payments = expense.payments.filter { $0.$debtor.id == userId }
            let paidAmount = payments.reduce(0) { $0 + $1.amountPaidInCents }
            
            amountPaid += paidAmount
            amountPendent += max(0, amountOwed - paidAmount)
            totalExpenses += amountOwed
            expensesCount += 1
        }
        
        // Collect unique participants
        for activity in activities {
            for participant in activity.participants {
                if participant.id != userId {
                    participantsSet.insert(participant.id!)
                }
            }
        }
        
        return ActivitySummaryResponse(
            amountPaidInCents: amountPaid,
            amountPendentInCents: amountPendent,
            totalExpensesAmount: totalExpenses,
            activitiesCount: activities.count,
            expensesCount: expensesCount,
            participantsCount: participantsSet.count
        )
    }
}
```

---

## 3. ExpenseController

### File: `Sources/App/Controllers/ExpenseController.swift`

```swift
import Vapor
import Fluent

struct ExpenseController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Routes are registered in routes.swift
    }
    
    // MARK: - Create Expense
    func create(req: Request) async throws -> CreateExpenseResponse {
        let user = try req.auth.require(User.self)
        
        guard let activityId = req.parameters.get("activityId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid activity ID")
        }
        
        let createRequest = try req.content.decode(CreateExpenseRequest.self)
        try createRequest.validate()
        
        // Verify activity exists
        guard let activity = try await Activity.find(activityId, on: req.db) else {
            throw Abort(.notFound, reason: "Activity not found")
        }
        
        // Verify user is participant in activity
        let isParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == activityId)
            .filter(\.$user.$id == user.id!)
            .first() != nil
        
        guard isParticipant else {
            throw Abort(.forbidden, reason: "You must be a participant of this activity")
        }
        
        // Verify payer exists and is participant
        guard let payer = try await User.find(createRequest.payerId, on: req.db) else {
            throw Abort(.notFound, reason: "Payer not found")
        }
        
        let payerIsParticipant = try await ActivityParticipant.query(on: req.db)
            .filter(\.$activity.$id == activityId)
            .filter(\.$user.$id == payer.id!)
            .first() != nil
        
        guard payerIsParticipant else {
            throw Abort(.badRequest, reason: "Payer must be a participant of the activity")
        }
        
        // Verify all participants exist and are activity participants
        let participants = try await User.query(on: req.db)
            .filter(\.$id ~~ createRequest.participantsIds)
            .all()
        
        guard participants.count == createRequest.participantsIds.count else {
            throw Abort(.notFound, reason: "One or more participants not found")
        }
        
        for participant in participants {
            let isActivityParticipant = try await ActivityParticipant.query(on: req.db)
                .filter(\.$activity.$id == activityId)
                .filter(\.$user.$id == participant.id!)
                .first() != nil
            
            guard isActivityParticipant else {
                throw Abort(.badRequest, reason: "All debtors must be participants of the activity")
            }
        }
        
        // Create expense
        let expense = Expense(
            name: createRequest.title,
            amountInCents: createRequest.amountInCents,
            payerID: createRequest.payerId,
            activityID: activityId
        )
        
        try await expense.save(on: req.db)
        
        // Calculate amount per participant
        let amountPerParticipant = createRequest.amountInCents / createRequest.participantsIds.count
        let remainder = createRequest.amountInCents % createRequest.participantsIds.count
        
        // Create expense participants (debtors)
        var participantDebts: [CreateExpenseResponse.ParticipantDebt] = []
        
        for (index, participantId) in createRequest.participantsIds.enumerated() {
            let participant = participants.first { $0.id == participantId }!
            
            // First participant gets the remainder
            let amountOwed = index == 0 ? amountPerParticipant + remainder : amountPerParticipant
            
            let expenseParticipant = ExpenseParticipant(
                expenseID: expense.id!,
                userID: participantId,
                amountOwedInCents: amountOwed
            )
            
            try await expenseParticipant.save(on: req.db)
            
            participantDebts.append(CreateExpenseResponse.ParticipantDebt(
                userId: participantId,
                userName: participant.name,
                amountOwedInCents: amountOwed
            ))
        }
        
        return CreateExpenseResponse(
            id: expense.id!,
            name: expense.name,
            amountInCents: expense.amountInCents,
            payerId: expense.$payer.id,
            activityId: expense.$activity.id,
            participants: participantDebts
        )
    }
    
    // MARK: - List Expenses
    func list(req: Request) async throws -> ExpenseListResponse {
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
        
        // Get all expenses for this activity
        let expenses = try await Expense.query(on: req.db)
            .filter(\.$activity.$id == activityId)
            .with(\.$payer)
            .all()
        
        var expenseItems: [ExpenseListItem] = []
        
        for expense in expenses {
            // Get participants for this expense
            let expenseParticipants = try await ExpenseParticipant.query(on: req.db)
                .filter(\.$expense.$id == expense.id!)
                .with(\.$user)
                .all()
            
            // Get payments for this expense
            let payments = try await ExpensePayment.query(on: req.db)
                .filter(\.$expense.$id == expense.id!)
                .all()
            
            let participants = expenseParticipants.map { ep in
                let totalPaid = payments
                    .filter { $0.$debtor.id == ep.$user.id }
                    .reduce(0) { $0 + $1.amountPaidInCents }
                
                let isPaidInFull = totalPaid >= ep.amountOwedInCents
                
                return ExpenseListItem.ParticipantInfo(
                    userId: ep.user.id!,
                    name: ep.user.name,
                    amountOwedInCents: ep.amountOwedInCents,
                    alreadyPaid: isPaidInFull
                )
            }
            
            expenseItems.append(ExpenseListItem(
                id: expense.id!,
                name: expense.name,
                totalAmountInCents: expense.amountInCents,
                createdAt: expense.createdAt,
                payer: ExpenseListItem.PayerInfo(
                    userId: expense.payer.id!,
                    name: expense.payer.name
                ),
                participants: participants
            ))
        }
        
        return ExpenseListResponse(expenses: expenseItems)
    }
    
    // MARK: - Mark Payment
    func markPayment(req: Request) async throws -> MarkPaymentResponse {
        let user = try req.auth.require(User.self)
        
        guard let expenseId = req.parameters.get("expenseId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid expense ID")
        }
        
        let paymentRequest = try req.content.decode(MarkPaymentRequest.self)
        
        // Get expense with relationships
        guard let expense = try await Expense.query(on: req.db)
            .filter(\.$id == expenseId)
            .with(\.$activity)
            .with(\.$payer)
            .first() else {
            throw Abort(.notFound, reason: "Expense not found")
        }
        
        // Verify debtor exists and is participant in the expense
        guard let expenseParticipant = try await ExpenseParticipant.query(on: req.db)
            .filter(\.$expense.$id == expenseId)
            .filter(\.$user.$id == paymentRequest.debtorId)
            .with(\.$user)
            .first() else {
            throw Abort(.notFound, reason: "Debtor not found in this expense")
        }
        
        // Create payment record
        let payment = ExpensePayment(
            expenseID: expenseId,
            debtorID: paymentRequest.debtorId,
            amountPaidInCents: expenseParticipant.amountOwedInCents
        )
        
        try await payment.save(on: req.db)
        
        // Get all participants with payment status
        let allParticipants = try await ExpenseParticipant.query(on: req.db)
            .filter(\.$expense.$id == expenseId)
            .with(\.$user)
            .all()
        
        let payments = try await ExpensePayment.query(on: req.db)
            .filter(\.$expense.$id == expenseId)
            .all()
        
        let participantStatuses = allParticipants.map { ep in
            let totalPaid = payments
                .filter { $0.$debtor.id == ep.$user.id }
                .reduce(0) { $0 + $1.amountPaidInCents }
            
            return MarkPaymentResponse.ParticipantPaymentStatus(
                userId: ep.user.id!,
                name: ep.user.name,
                amountOwedInCents: ep.amountOwedInCents,
                amountPaidInCents: totalPaid,
                isPaidInFull: totalPaid >= ep.amountOwedInCents
            )
        }
        
        return MarkPaymentResponse(
            success: true,
            message: "Payment recorded successfully",
            expense: MarkPaymentResponse.ExpensePaymentDetail(
                id: expense.id!,
                name: expense.name,
                amountInCents: expense.amountInCents,
                participants: participantStatuses
            )
        )
    }
}
```

---

## 4. ParticipantController

### File: `Sources/App/Controllers/ParticipantController.swift`

```swift
import Vapor
import Fluent

struct ParticipantController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Routes are registered in routes.swift
    }
    
    // MARK: - List Participants
    func list(req: Request) async throws -> ParticipantsListResponse {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        let authenticatedUser = try req.auth.require(User.self)
        
        // Users can only view their own participants
        guard authenticatedUser.id == userId else {
            throw Abort(.forbidden, reason: "You can only view your own participants")
        }
        
        // Get all activities for this user
        let userActivities = try await ActivityParticipant.query(on: req.db)
            .filter(\.$user.$id == userId)
            .with(\.$activity) { activity in
                activity.with(\.$participants)
            }
            .all()
        
        // Collect all unique participants (excluding the user themselves)
        var participantMap: [UUID: (user: User, activityCount: Int)] = [:]
        
        for activityParticipant in userActivities {
            let activity = activityParticipant.activity
            
            for participant in activity.participants {
                guard participant.id != userId else { continue }
                
                if let existing = participantMap[participant.id!] {
                    participantMap[participant.id!] = (
                        user: existing.user,
                        activityCount: existing.activityCount + 1
                    )
                } else {
                    participantMap[participant.id!] = (
                        user: participant,
                        activityCount: 1
                    )
                }
            }
        }
        
        let participants = participantMap.values.map { entry in
            ParticipantsListResponse.ParticipantItem(
                id: entry.user.id!,
                name: entry.user.name,
                email: entry.user.email,
                relatedActivitiesAmount: entry.activityCount
            )
        }.sorted { $0.relatedActivitiesAmount > $1.relatedActivitiesAmount }
        
        return ParticipantsListResponse(participants: participants)
    }
}
```

---

## Summary

This part covered:

1. ✅ **AuthController** - Complete authentication:
   - Sign up with validation and duplicate checking
   - Sign in with password verification
   - Get user profile
   - JWT token generation

2. ✅ **ActivityController** - Full activity management:
   - Create activity and auto-add creator as participant
   - Update activity with authorization checks
   - List user's activities with stats
   - Get activity details with participants and expenses
   - Activity summary with payment statistics

3. ✅ **ExpenseController** - Complete expense handling:
   - Create expense with validation
   - Automatic amount splitting among participants
   - List expenses with payment status
   - Mark payments and track payment history

4. ✅ **ParticipantController** - Participant management:
   - List all participants user has interacted with
   - Count activities per participant
   - Sorted by most frequent collaborators

**Next up: Part 4 - Balance Controller and Services**

This will include the complex compensation logic!