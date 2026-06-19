import XCTest

final class LocalizationSmokeTests: XCTestCase {
    func testDutchAndEnglishLocalizableResourcesExist() {
        let bundle = Bundle(for: LocalizationSmokeTests.self)
        let appBundleURL = bundle.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MissionZebra.app")
        let appBundle = Bundle(url: appBundleURL) ?? Bundle.main

        XCTAssertNotNil(appBundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "nl"))
        XCTAssertNotNil(appBundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en"))
    }
}
