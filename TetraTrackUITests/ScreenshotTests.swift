//
//  ScreenshotTests.swift
//  TetraTrackUITests
//
//  Fully automated screenshot capture for App Store Connect.
//
//  The -screenshotMode launch argument triggers auto-generation of
//  demonstration data on app launch, so no manual steps are needed.
//
//  Run with:
//    xcodebuild -scheme TetraTrack -sdk iphonesimulator \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
//      -resultBundlePath /tmp/TetraTrackScreenshots.xcresult \
//      test -only-testing:TetraTrackUITests/ScreenshotTests
//
//  Then extract screenshots with: ./Scripts/automated_screenshots.sh
//

import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchArguments = ["-screenshotMode"]
        app.launch()

        // Wait for app to fully load and generate demo data
        sleep(4)
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

    // Helper to navigate back to home
    private func navigateHome() {
        while app.navigationBars.buttons["Back"].exists {
            app.navigationBars.buttons["Back"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    // MARK: - iPhone Screenshots (10 total for App Store Connect)

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
    func test03_RideDetail() throws {
        navigateHome()

        // Navigate to Training History then into first ride detail
        let historyCard = app.staticTexts["Training History"]
        if historyCard.waitForExistence(timeout: 5) {
            historyCard.tap()
            sleep(1)

            let cells = app.cells
            if cells.count > 0 {
                cells.element(boundBy: 0).tap()
                sleep(1)
                captureScreenshot("03_Ride_Detail")
            }
        }
    }

    @MainActor
    func test04_CompetitionCalendar() throws {
        navigateHome()

        // Tap on Competitions card
        let competitionCard = app.staticTexts["Competitions"]
        if competitionCard.waitForExistence(timeout: 5) {
            competitionCard.tap()
            sleep(1)
            captureScreenshot("04_Competition_Calendar")
        }
    }

    @MainActor
    func test05_HorseProfile() throws {
        navigateHome()

        // Go to Settings
        app.buttons["gearshape"].firstMatch.tap()
        sleep(1)

        // Tap on My Horses
        let horsesRow = app.staticTexts["My Horses"]
        if horsesRow.waitForExistence(timeout: 5) {
            horsesRow.tap()
            sleep(1)

            // Tap on first horse to show detail
            let cells = app.cells
            if cells.count > 0 {
                cells.element(boundBy: 0).tap()
                sleep(1)
                captureScreenshot("05_Horse_Profile")
            }
        }
    }

    @MainActor
    func test06_RunningView() throws {
        navigateHome()

        // Tap on Running
        let runningCard = app.staticTexts["Running"]
        if runningCard.waitForExistence(timeout: 5) {
            runningCard.tap()
            sleep(1)
            captureScreenshot("06_Running")
        }
    }

    @MainActor
    func test07_SwimmingView() throws {
        navigateHome()

        // Tap on Swimming
        let swimmingCard = app.staticTexts["Swimming"]
        if swimmingCard.waitForExistence(timeout: 5) {
            swimmingCard.tap()
            sleep(1)
            captureScreenshot("07_Swimming")
        }
    }

    @MainActor
    func test08_ShootingView() throws {
        navigateHome()

        // Tap on Shooting
        let shootingCard = app.staticTexts["Shooting"]
        if shootingCard.waitForExistence(timeout: 5) {
            shootingCard.tap()
            sleep(1)
            captureScreenshot("08_Shooting")
        }
    }

    @MainActor
    func test09_SessionInsights() throws {
        navigateHome()

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
                captureScreenshot("09_Session_Insights")
            }
        }
    }

    @MainActor
    func test10_LiveSharing() throws {
        navigateHome()

        // Tap on Live Sharing
        let liveSharingCard = app.staticTexts["Live Sharing"]
        if liveSharingCard.waitForExistence(timeout: 5) {
            liveSharingCard.tap()
            sleep(1)
            captureScreenshot("10_Live_Sharing")
        }
    }
}

// MARK: - iPad Screenshots
// iPad runs in review-only mode (no discipline capture views)
// Run with: xcodebuild -scheme TetraTrack -sdk iphonesimulator \
//   -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
//   -resultBundlePath /tmp/TetraTrackiPadScreenshots.xcresult \
//   test -only-testing:TetraTrackUITests/iPadScreenshotTests

final class iPadScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchArguments = ["-screenshotMode"]
        app.launch()
        sleep(4)
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
