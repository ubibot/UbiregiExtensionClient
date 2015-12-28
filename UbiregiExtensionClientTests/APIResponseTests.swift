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
                response.trySuccessResponse { res in
                    expect(res).to(beIdenticalTo(response))
                }
            }
            
            it("does not yield on error response") {
                let response = UXCAPIErrorResponse(error: NSError(domain: "TestDomain", code: 0, userInfo: [:]))
                response.trySuccessResponse { res in
                    expect("not to be reached").to(equal("but is reached"))
                }
            }
        }
        
        describe("#tryErrorResponse") {
            it("does not yield on success esponse") {
                let response = UXCAPISuccessResponse(code: 200, header: [:], body: NSData())
                response.tryErrorResponse { res in
                    expect("not to be reached").to(equal("but is reached"))
                }
            }
            
            it("yields itself on error response") {
                let response = UXCAPIErrorResponse(error: NSError(domain: "TestDomain", code: 0, userInfo: [:]))
                response.tryErrorResponse { res in
                    expect(res).to(beIdenticalTo(response))
                }
            }
        }
    }
}