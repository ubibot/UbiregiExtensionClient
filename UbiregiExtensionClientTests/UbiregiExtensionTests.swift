import XCTest
import Quick
import Nimble
import Swifter
@testable import UbiregiExtensionClient

class UbiregiExtensionTests: QuickSpec {
    override func spec() {
        var client: UXCUbiregiExtension!
        
        describe("UXCUbiregiExtension") {
            beforeEach {
                client = UXCUbiregiExtension(hostname: "localhost", port: 8081, numericAddress: nil)
            }
            
            describe("#requestJSON") {
                context("GET") {
                    it("sends GET request") {
                        withSwifter { server in
                            server["/test"] = { request in HttpResponse.OK(HttpResponseBody.JSON([])) }
                            
                            waitUntil { done in
                                client.requestJSON("/test", query: [:], method: .GET, body: nil) { response in
                                    try! response.trySuccessResponse { response in
                                        expect(response.code).to(equal(200))
                                        expect(response.JSONBody?.isEqual([])).to(beTrue())
                                    }
                                    done()
                                }
                            }
                        }
                    }
                }
                
                context("POST") {
                    it("sends POST request") {
                        withSwifter { server in
                            server["/test"] = { request in
                                expect(request.method).to(equal("POST"))
                                let json = try! NSJSONSerialization.JSONObjectWithData(request.body!.dataUsingEncoding(NSUTF8StringEncoding)!, options: NSJSONReadingOptions.MutableContainers)
                                return HttpResponse.OK(HttpResponseBody.JSON(json))
                            }
                            
                            waitUntil { done in
                                client.requestJSON("/test", query: [:], method: .POST, body: ["test": true]) { response in
                                    try! response.trySuccessResponse { response in
                                        expect(response.JSONBody?.isEqual(["test": true])).to(beTrue())
                                    }
                                    done()
                                }
                            }
                        }
                    }
                }
                
                context("PUT") {
                    it("sends PUT request") {
                        withSwifter { server in
                            server["/test"] = { request in
                                expect(request.method).to(equal("PUT"))
                                let json = try! NSJSONSerialization.JSONObjectWithData(request.body!.dataUsingEncoding(NSUTF8StringEncoding)!, options: NSJSONReadingOptions.MutableContainers)
                                return HttpResponse.OK(HttpResponseBody.JSON(json))
                            }
                            
                            waitUntil { done in
                                client.requestJSON("/test", query: [:], method: .PUT, body: ["test": true]) { response in
                                    try! response.trySuccessResponse { response in
                                        expect(response.JSONBody?.isEqual(["test": true])).to(beTrue())
                                    }
                                    done()
                                }
                            }
                        }
                    }
                }
                
                describe("status update") {
                    it("updates status to .Connected") {
                        withSwifter { server in
                            server["/test"] = { request in HttpResponse.OK(HttpResponseBody.JSON([1,2,3])) }
                            
                            waitUntil { done in
                                client.requestJSON("/test", query: [:], method: .PUT, body: ["test": true]) { response in
                                    done()
                                }
                            }
                            
                            expect(client.status).to(equal(UXCExtensionStatus.Connected))
                        }
                    }

                    it("updates status to .Error") {
                        waitUntil(timeout: 3) { done in
                            client.requestJSON("/test", query: [:], method: .PUT, body: ["test": true]) { response in
                                done()
                            }
                        }
                        
                        expect(client.status).to(equal(UXCExtensionStatus.Error))
                    }
                }
            }
        }
    }
}