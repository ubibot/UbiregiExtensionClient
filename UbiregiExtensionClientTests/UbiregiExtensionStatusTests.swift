import XCTest
import Quick
import Nimble
import Swifter
@testable import UbiregiExtensionClient

class UbiregiExtensionStatusTests: QuickSpec {
    override func spec() {
        var client: UXCUbiregiExtension!
        
        beforeEach {
            client = UXCUbiregiExtension(hostname: "localhost", port: 8081, numericAddress: nil)
        }

        describe("#updateStatus") {
            let jsonResponse: AnyObject = [
                "version": "1.2.3",
                "product_version": "October, 2015",
                "release": "1-3",
                "printers": [],
                "barcodes": []
            ]
            
            describe("request") {
                it("sends timestamp and reload to /status") {
                    withSwifter { server in
                        server["/status"] = { request in
                            let d = dictionary(request.urlParams)
                            expect(d["timestamp"]).notTo(beEmpty())
                            expect(d["reload"]).to(equal("false"))
                            return HttpResponse.OK(HttpResponseBody.JSON(jsonResponse))
                        }
                        
                        waitUntil { done in
                            client.updateStatus {
                                done()
                            }
                        }
                    }
                }
                
                it("sends GET request to /status with reload=true parameter") {
                    withSwifter { server in
                        server["/status"] = { (request: HttpRequest) in
                            let d = dictionary(request.urlParams)
                            expect(d["reload"]).to(equal("true"))
                            return HttpResponse.OK(HttpResponseBody.JSON(jsonResponse))
                        }
                        
                        waitUntil { done in
                            client.updateStatus(true) {
                                done()
                            }
                        }
                    }
                }
            }
            
            describe("response") {
                it("updates status") {
                    withSwifter { server in
                        server["/status"] = { request in
                            return HttpResponse.OK(HttpResponseBody.JSON(jsonResponse))
                        }
                        
                        waitUntil { done in
                            client.updateStatus {
                                expect(client.status?.isEqual(jsonResponse)).to(beTrue())
                                done()
                            }
                        }
                    }
                }
                
                context("connection failure") {
                    it("does not update status") {
                        waitUntil(timeout: 3) { done in
                            client.updateStatus {
                                expect(client.status).to(beNil())
                                done()
                            }
                        }
                    }
                }
                
                context("http error") {
                    it("does not update status") {
                        withSwifter { server in
                            server["/status"] = { request in
                                return HttpResponse.NotFound
                            }
                            
                            waitUntil { done in
                                client.updateStatus {
                                    expect(client.status).to(beNil())
                                    done()
                                }
                            }
                        }
                    }
                }
            }
        }
        
        describe("version") {
            it("returns version from status") {
                client._status = ["version": "1.2.3"]
                let v = client.version
                
                expect(v?.string).to(equal("1.2.3"))
            }
            
            it("returns nil if no status is given") {
                client._status = nil
                let v = client.version
                
                expect(v).to(beNil())
            }
            
            it("returns default version (1.0.0) if no version attribute exists") {
                client._status = [:]
                let v = client.version
                
                expect(v?.string).to(equal("1.0.0"))
            }
        }
    }
}