//
//  ScreenshotTests.swift
//  TrackRideUITests
//
//  Automated screenshot capture for App Store Connect
//
//  IMPORTANT: Before running these tests:
//  1. Launch the app manually
//  2. Go to Settings > Generate Screenshot Data
//  3. Then run these UI tests to capture all screenshots
//
//  Run with: xcodebuild -scheme TrackRide -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:TrackRideUITests/ScreenshotTests
//

import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launch()

        // Wait for app to fully load
        sleep(2)
    }

    override func tearDownWithError() throws {
        // Screenshots are saved automatically by Xcode
    }

    // MARK: - Screenshot Helper

    func captureScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - iPhone Screenshots

    @MainActor
    func test01_HomeScreen() throws {
        // Home/Disciplines view
        captureScreenshot("01_Home_Disciplines")
    }

    @MainActor
    func test02_RidingTrackingView() throws {
        // Tap on Riding card
        let ridingCard = app.staticTexts["Riding"]
        if ridingCard.waitForExistence(timeout: 5) {
            ridingCard.tap()
            sleep(1)
            captureScreenshot("02_Riding_BigButton")
        }
    }

    @MainActor
    func test03_TrainingHistory() throws {
        // Navigate back if needed
        if app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
        }

        // Tap on Training History
        let historyCard = app.staticTexts["Training History"]
        if historyCard.waitForExistence(timeout: 5) {
            historyCard.tap()
            sleep(1)
            captureScreenshot("03_Training_History")

            // Tap on first ride to see detail
            let cells = app.cells
            if cells.count > 0 {
                cells.element(boundBy: 0).tap()
                sleep(1)
                captureScreenshot("04_Ride_Detail")
            }
        }
    }

    @MainActor
    func test05_CompetitionCalendar() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Tap on Competition Calendar
        let competitionCard = app.staticTexts["Competition Calendar"]
        if competitionCard.waitForExistence(timeout: 5) {
            competitionCard.tap()
            sleep(1)
            captureScreenshot("05_Competition_Calendar")
        }
    }

    @MainActor
    func test06_HorseProfiles() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Go to Settings
        app.buttons["gearshape"].firstMatch.tap()
        sleep(1)

        // Tap on My Horses
        let horsesRow = app.staticTexts["My Horses"]
        if horsesRow.waitForExistence(timeout: 5) {
            horsesRow.tap()
            sleep(1)
            captureScreenshot("06_Horse_List")

            // Tap on first horse
            let cells = app.cells
            if cells.count > 0 {
                cells.element(boundBy: 0).tap()
                sleep(1)
                captureScreenshot("07_Horse_Detail")
            }
        }
    }

    @MainActor
    func test08_RunningView() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Tap on Running
        let runningCard = app.staticTexts["Running"]
        if runningCard.waitForExistence(timeout: 5) {
            runningCard.tap()
            sleep(1)
            captureScreenshot("08_Running")
        }
    }

    @MainActor
    func test09_SwimmingView() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Tap on Swimming
        let swimmingCard = app.staticTexts["Swimming"]
        if swimmingCard.waitForExistence(timeout: 5) {
            swimmingCard.tap()
            sleep(1)
            captureScreenshot("09_Swimming")
        }
    }

    @MainActor
    func test10_ShootingView() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Tap on Shooting
        let shootingCard = app.staticTexts["Shooting"]
        if shootingCard.waitForExistence(timeout: 5) {
            shootingCard.tap()
            sleep(1)
            captureScreenshot("10_Shooting")
        }
    }

    @MainActor
    func test11_InsightsView() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Tap on Insights
        let insightsCard = app.staticTexts["Insights"]
        if insightsCard.waitForExistence(timeout: 5) {
            insightsCard.tap()
            sleep(1)
            captureScreenshot("11_AI_Insights")
        }
    }

    @MainActor
    func test12_FamilyTracking() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Tap on Family Tracking
        let familyCard = app.staticTexts["Family Tracking"]
        if familyCard.waitForExistence(timeout: 5) {
            familyCard.tap()
            sleep(1)
            captureScreenshot("12_Family_Safety")
        }
    }
}
