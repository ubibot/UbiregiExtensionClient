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

            describe("notification") {
                it("posts notification on updateStatus call") {
                    withSwifter { server in
                        server["/status"] = { request in HttpResponse.OK(HttpResponseBody.JSON(jsonResponse)) }
                        
                        self.expectationForNotification(UbiregiExtensionDidUpdateStatusNotification, object: client, handler: nil)
                        
                        waitUntil { done in
                            client.updateStatus {
                                done()
                            }
                        }
                        
                        self.waitForExpectationsWithTimeout(3, handler: nil)
                    }
                }
            }
            
            describe("device availability") {
                let responseWithDevices: AnyObject = [
                    "version": "1.2.3",
                    "product_version": "October, 2015",
                    "release": "1-3",
                    "printers": ["present"],
                    "barcodes": ["present"]
                ]

                let responseWithoutDevices: AnyObject = [
                    "version": "1.2.3",
                    "product_version": "October, 2015",
                    "release": "1-3",
                    "printers": [],
                    "barcodes": []
                ]

                it("updates device availability to true") {
                    withSwifter { server in
                        server["/status"] = { request in .OK(.Json(responseWithDevices)) }
                        
                        client._hasBarcodeScanner = false
                        client._hasPrinter = false
                        
                        waitUntil { done in
                            client.updateStatus {
                                done()
                            }
                        }
                        
                        expect(client.hasBarcodeScanner).to(beTrue())
                        expect(client.hasPrinter).to(beTrue())
                    }
                }
                
                it("updates device availability to false") {
                    withSwifter { server in
                        server["/status"] = { request in .OK(.Json(responseWithoutDevices)) }
                        
                        client._hasPrinter = true
                        client._hasBarcodeScanner = true
                        
                        waitUntil { done in
                            client.updateStatus { done() }
                        }
                        
                        expect(client.hasPrinter).to(beFalse())
                        expect(client.hasBarcodeScanner).to(beFalse())
                    }
                }
                
                it("posts notification on availability update") {
                    withSwifter { server in
                        server["/status"] = { request in .OK(.Json(responseWithoutDevices)) }
                        
                        client._hasPrinter = true
                        client._hasBarcodeScanner = true
                        
                        self.expectationForNotification(UbiregiExtensionDidUpdateBarcodeScannerAvailabilityNotification, object: client, handler: nil)
                        self.expectationForNotification(UbiregiExtensionDidUpdatePrinterAvailabilityNotification, object: client, handler: nil)
                        
                        waitUntil { done in
                            client.updateStatus { done() }
                        }
                        
                        self.waitForExpectationsWithTimeout(1, handler: nil)
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
