import Vapor

func routes(_ app: Application) throws {
    // Register all controllers
    try app.routes.register(collection: DriversUIController())
    try app.routes.register(collection: VehicleUIController())
    try app.routes.register(collection: TripUIController())
    try app.routes.register(collection: DriverFinanceController())


    // Register the new landing controller
    try app.routes.register(collection: LandingController())

    // Root redirect to welcome page
    app.get { req in
        req.redirect(to: "/products/gofloradriver")
    }
}
