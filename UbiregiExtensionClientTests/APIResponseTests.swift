import XCTest
import Quick
import Nimble
@testable import UbiregiExtensionClient

class APIResponseTests: QuickSpec {
    override func spec() {
        describe("UXCAPISuccessResponse") {
            describe("JSONBody") {
                context("Content-Type is application/json") {
                    it("returns object represented by body") {
                        let string = "[]"
                        let result = UXCAPISuccessResponse(code: 200, header: ["Content-Type": "application/json"], body: string.dataUsingEncoding(NSUTF8StringEncoding)!)
                        
                        expect(result.JSONBody!.isEqual([])).to(beTrue())
                    }
                    
                    it("returns nil if data can not be parsed as JSON") {
                        let string = "broken json"
                        let result = UXCAPISuccessResponse(code: 200, header: ["Content-Type": "application/json"], body: string.dataUsingEncoding(NSUTF8StringEncoding)!)
                        
                        expect(result.JSONBody).to(beNil())
                    }
                }
                
                context("Content-Type is application/json; charset=utf-8") {
                    it("returns object represented by body") {
                        let string = "[]"
                        let result = UXCAPISuccessResponse(code: 200, header: ["Content-Type": "application/json; charset=utf8"], body: string.dataUsingEncoding(NSUTF8StringEncoding)!)
                        
                        expect(result.JSONBody!.isEqual([])).to(beTrue())
                    }
                }
                
                context("Content-Type is not application/json") {
                    it("returns nil") {
                        let result = UXCAPISuccessResponse(code: 200, header: ["Content-Type": "text/html"], body: "".dataUsingEncoding(NSUTF8StringEncoding)!)
                        
                        expect(result.JSONBody).to(beNil())
                    }
                }
            }
        }
        
        describe("#trySuccessResponse") {
            it("yields itself on success response") {
                let response = UXCAPISuccessResponse(code: 200, header: [:], body: NSData())
                try! response.trySuccessResponse { res in
                    expect(res).to(beIdenticalTo(response))
                }
            }
            
            it("throws an error on error response") {
                do {
                    let response = UXCAPIErrorResponse(error: NSError(domain: "TestDomain", code: 0, userInfo: [:]))
                    try response.trySuccessResponse { res in }
                    expect("not to be reached").to(equal("but is reached"))
                } catch _ {
                    // ok
                }
            }
        }
        
        describe("#tryErrorResponse") {
            it("yields itself on success response") {
                do {
                    let response = UXCAPISuccessResponse(code: 200, header: [:], body: NSData())
                    try response.tryErrorResponse { res in }
                    expect("not to be reached").to(equal("but is reached"))
                } catch _ {
                    // ok
                }
            }
            
            it("yields itself on error response") {
                let response = UXCAPIErrorResponse(error: NSError(domain: "TestDomain", code: 0, userInfo: [:]))
                try! response.tryErrorResponse { res in
                    expect(res).to(beIdenticalTo(response))
                }
            }
        }
    }
}