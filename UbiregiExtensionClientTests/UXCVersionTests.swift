import XCTest
import Quick
import Nimble
@testable import UbiregiExtensionClient

class UbiregiExtensionVersionTests: QuickSpec {
    override func spec() {
        it("parses version string") {
            let v = UXCVersion(string: "1.2.3")
            expect(v.major).to(equal(1))
            expect(v.minor).to(equal(2))
            expect(v.patch).to(equal(3))
            expect(v.label).to(beNil())
        }
        
        it("parses version string with missing components") {
            let v = UXCVersion(string: "1.2")
            expect(v).to(equal(UXCVersion(string: "1.2.0")))
        }
        
        it("parses version string with label") {
            let v = UXCVersion(string: "1.2.3-beta1")
            expect(v.major).to(equal(1))
            expect(v.minor).to(equal(2))
            expect(v.patch).to(equal(3))
            expect(v.label!).to(equal("beta1"))
        }
        
        it("parses version string with label including hyphen") {
            let v = UXCVersion(string: "1.2.3-beta1-ios8")
            expect(v.major).to(equal(1))
            expect(v.minor).to(equal(2))
            expect(v.patch).to(equal(3))
            expect(v.label!).to(equal("beta1-ios8"))
        }
    }
}