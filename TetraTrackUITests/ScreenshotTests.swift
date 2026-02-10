//
//  ScreenshotTests.swift
//  TetraTrackUITests
//
//  Automated screenshot capture for App Store Connect
//
//  IMPORTANT: Before running these tests:
//  1. Launch the app manually
//  2. Go to Settings > Generate Screenshot Data
//  3. Then run these UI tests to capture all screenshots
//
//  Run with: xcodebuild -scheme TetraTrack -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:TetraTrackUITests/ScreenshotTests
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

        // Tap on Competitions card
        let competitionCard = app.staticTexts["Competitions"]
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
    func test11_SessionInsights() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Tap on Training History
        let historyCard = app.staticTexts["Training History"]
        if historyCard.waitForExistence(timeout: 5) {
            historyCard.tap()
            sleep(1)

            // Tap on Session Insights tab (segmented picker button)
            let insightsTab = app.buttons["Session Insights"]
            if insightsTab.waitForExistence(timeout: 3) {
                insightsTab.tap()
                sleep(1)
                captureScreenshot("11_Session_Insights")
            }
        }
    }

    @MainActor
    func test12_LiveSharing() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Tap on Live Sharing
        let liveSharingCard = app.staticTexts["Live Sharing"]
        if liveSharingCard.waitForExistence(timeout: 5) {
            liveSharingCard.tap()
            sleep(1)
            captureScreenshot("12_Live_Sharing")
        }
    }

    // MARK: - New Feature Screenshots

    @MainActor
    func test13_CompetitionDetail_CalendarSync() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Navigate to Competitions
        let competitionCard = app.staticTexts["Competitions"]
        if competitionCard.waitForExistence(timeout: 5) {
            competitionCard.tap()
            sleep(1)

            // Tap on first competition by name (ScrollView rows, not List cells)
            let competitionName = app.staticTexts["Area Tetrathlon Championships"].firstMatch
            if competitionName.waitForExistence(timeout: 5) {
                competitionName.tap()
                sleep(1)
                captureScreenshot("13_Competition_Detail_Calendar_Sync")
            }
        }
    }

    @MainActor
    func test14_TasksWithReminders() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Tap on Tasks card from home screen
        let tasksCard = app.staticTexts["Tasks"]
        if tasksCard.waitForExistence(timeout: 5) {
            tasksCard.tap()
            sleep(1)
            captureScreenshot("14_Tasks_Reminders")
        }
    }

    @MainActor
    func test15_RideDetail_SensorExport() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Navigate to Training History
        let historyCard = app.staticTexts["Training History"]
        if historyCard.waitForExistence(timeout: 5) {
            historyCard.tap()
            sleep(1)

            // Tap on first ride
            let cells = app.cells
            if cells.count > 0 {
                cells.element(boundBy: 0).tap()
                sleep(1)

                // Scroll down to find the sensor export section
                let scrollView = app.scrollViews.firstMatch
                scrollView.swipeUp()
                sleep(1)
                scrollView.swipeUp()
                sleep(1)
                captureScreenshot("15_Ride_Detail_Sensor_Export")
            }
        }
    }

    @MainActor
    func test16_RunningWithCountdown() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Navigate to Running
        let runningCard = app.staticTexts["Running"]
        if runningCard.waitForExistence(timeout: 5) {
            runningCard.tap()
            sleep(1)
            captureScreenshot("16_Running_Menu")

            // Tap Run to trigger countdown
            let runButton = app.staticTexts["Run"]
            if runButton.waitForExistence(timeout: 3) {
                runButton.tap()
                sleep(1)
                captureScreenshot("17_Running_Countdown")

                // Cancel the countdown
                let cancelButton = app.buttons["Cancel"]
                if cancelButton.waitForExistence(timeout: 3) {
                    cancelButton.tap()
                    sleep(1)
                }
            }
        }
    }

    @MainActor
    func test18_SwimmingOpenWater() throws {
        // Navigate back to home
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Navigate to Swimming
        let swimmingCard = app.staticTexts["Swimming"]
        if swimmingCard.waitForExistence(timeout: 5) {
            swimmingCard.tap()
            sleep(1)
            captureScreenshot("18_Swimming_Menu")
        }
    }
}

// MARK: - iPad Screenshots
// iPad runs in review-only mode (no discipline capture views)
// Run with: xcodebuild -scheme TetraTrack -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test -only-testing:TetraTrackUITests/iPadScreenshotTests

final class iPadScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launch()
        sleep(2)
    }

    override func tearDownWithError() throws {}

    func captureScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // Helper to navigate back to home
    private func navigateHome() {
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    @MainActor
    func test01_iPad_HomeScreen() throws {
        // iPad home with 2-column grid layout
        captureScreenshot("iPad_01_Home")
    }

    @MainActor
    func test02_iPad_TrainingHistory() throws {
        let historyCard = app.staticTexts["Training History"]
        if historyCard.waitForExistence(timeout: 5) {
            historyCard.tap()
            sleep(1)
            captureScreenshot("iPad_02_Training_History")
        }
    }

    @MainActor
    func test03_iPad_RideDetail() throws {
        navigateHome()

        let historyCard = app.staticTexts["Training History"]
        if historyCard.waitForExistence(timeout: 5) {
            historyCard.tap()
            sleep(1)

            let cells = app.cells
            if cells.count > 0 {
                cells.element(boundBy: 0).tap()
                sleep(1)
                captureScreenshot("iPad_03_Ride_Detail")
            }
        }
    }

    @MainActor
    func test04_iPad_SessionInsights() throws {
        navigateHome()

        let historyCard = app.staticTexts["Training History"]
        if historyCard.waitForExistence(timeout: 5) {
            historyCard.tap()
            sleep(1)

            let insightsTab = app.buttons["Session Insights"]
            if insightsTab.waitForExistence(timeout: 3) {
                insightsTab.tap()
                sleep(1)
                captureScreenshot("iPad_04_Session_Insights")
            }
        }
    }

    @MainActor
    func test05_iPad_Competitions() throws {
        navigateHome()

        let competitionCard = app.staticTexts["Competitions"]
        if competitionCard.waitForExistence(timeout: 5) {
            competitionCard.tap()
            sleep(1)
            captureScreenshot("iPad_05_Competitions")
        }
    }

    @MainActor
    func test06_iPad_CompetitionDetail() throws {
        navigateHome()

        let competitionCard = app.staticTexts["Competitions"]
        if competitionCard.waitForExistence(timeout: 5) {
            competitionCard.tap()
            sleep(1)

            let competitionName = app.staticTexts["Area Tetrathlon Championships"].firstMatch
            if competitionName.waitForExistence(timeout: 5) {
                competitionName.tap()
                sleep(1)
                captureScreenshot("iPad_06_Competition_Detail")
            }
        }
    }

    @MainActor
    func test07_iPad_Tasks() throws {
        navigateHome()

        let tasksCard = app.staticTexts["Tasks"]
        if tasksCard.waitForExistence(timeout: 5) {
            tasksCard.tap()
            sleep(1)
            captureScreenshot("iPad_07_Tasks")
        }
    }

    @MainActor
    func test08_iPad_LiveSharing() throws {
        navigateHome()

        let liveSharingCard = app.staticTexts["Live Sharing"]
        if liveSharingCard.waitForExistence(timeout: 5) {
            liveSharingCard.tap()
            sleep(1)
            captureScreenshot("iPad_08_Live_Sharing")
        }
    }

    @MainActor
    func test09_iPad_HorseList() throws {
        navigateHome()

        // Go to Settings
        app.buttons["gearshape"].firstMatch.tap()
        sleep(1)

        let horsesRow = app.staticTexts["My Horses"]
        if horsesRow.waitForExistence(timeout: 5) {
            horsesRow.tap()
            sleep(1)
            captureScreenshot("iPad_09_Horse_List")
        }
    }

    @MainActor
    func test10_iPad_HorseDetail() throws {
        navigateHome()

        app.buttons["gearshape"].firstMatch.tap()
        sleep(1)

        let horsesRow = app.staticTexts["My Horses"]
        if horsesRow.waitForExistence(timeout: 5) {
            horsesRow.tap()
            sleep(1)

            let cells = app.cells
            if cells.count > 0 {
                cells.element(boundBy: 0).tap()
                sleep(1)
                captureScreenshot("iPad_10_Horse_Detail")
            }
        }
    }
}
