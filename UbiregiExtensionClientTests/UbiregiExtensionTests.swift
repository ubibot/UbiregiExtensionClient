import XCTest
import Quick
import Nimble
import Swifter
@testable import UbiregiExtensionClient

class UbiregiExtensionTests: QuickSpec {
    override func spec() {
        var client: UXCUbiregiExtension!
        var trace: NotificationTrace!
        
        describe("UXCUbiregiExtension") {
            beforeEach {
                client = UXCUbiregiExtension(hostname: "localhost", port: 8081, numericAddress: nil)
                trace = NotificationTrace()
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
                
                describe("connectionStatus update") {
                    it("updates connectionStatus to .Connected") {
                        withSwifter { server in
                            server["/test"] = { request in HttpResponse.OK(HttpResponseBody.JSON([1,2,3])) }
                            
                            waitUntil { done in
                                client.requestJSON("/test", query: [:], method: .PUT, body: ["test": true]) { response in
                                    done()
                                }
                            }
                            
                            expect(client.connectionStatus).to(equal(UXCConnectionStatus.Connected))
                        }
                    }

                    it("updates connectionStatus to .Error") {
                        waitUntil(timeout: 3) { done in
                            client.requestJSON("/test", query: [:], method: .PUT, body: ["test": true]) { response in
                                done()
                            }
                        }
                        
                        expect(client.connectionStatus).to(equal(UXCConnectionStatus.Error))
                    }
                    
                    it("does not set connectionStatus=Failure on timeout if allowTimeout is true") {
                        withSwifter { server in
                            server["/test"] = { request in
                                NSThread.sleepForTimeInterval(1.5)
                                return HttpResponse.OK(HttpResponseBody.JSON([1,2,3]))
                            }
                            
                            waitUntil(timeout: 4) { done in
                                client.requestJSON("/test", query: [:], method: .GET, body: nil, timeout: 1, allowTimeout: true) { response in
                                    expect(response is UXCAPIErrorResponse).to(beTrue())
                                    done()
                                }
                            }
                            
                            expect(client.connectionStatus).notTo(equal(UXCConnectionStatus.Error))
                        }
                    }
                    
                    describe("notifications") {
                        beforeEach {
                            NSNotificationCenter.defaultCenter().addObserver(trace, selector: "didReceiveNotification:", name: UbiregiExtensionDidUpdateConnectionStatusNotification, object: client)
                        }
                        
                        afterEach {
                            NSNotificationCenter.defaultCenter().removeObserver(trace)
                        }

                        it("posts notification on connectionStatus update") {
                            withSwifter { server in
                                server["/test"] = { request in HttpResponse.OK(HttpResponseBody.JSON([1,2,3])) }
                                
                                waitUntil { done in
                                    client.requestJSON("/test", query: [:], method: .PUT, body: ["test": true]) { response in
                                        done()
                                    }
                                }
                                
                                waitUntil { done in
                                    dispatch_async(dispatch_get_main_queue()) {
                                        expect(trace.notificationNames()).to(equal([UbiregiExtensionDidUpdateConnectionStatusNotification]))
                                        done()
                                    }
                                }
                            }
                        }

                        it("does not post notification if connectionStatus is not changed") {
                            withSwifter { server in
                                server["/test"] = { request in HttpResponse.OK(HttpResponseBody.JSON([1,2,3])) }
                                
                                client._connectionStatus = .Connected
                                
                                waitUntil { done in
                                    client.requestJSON("/test", query: [:], method: .PUT, body: ["test": true]) { response in
                                        done()
                                    }
                                }
                                
                                waitUntil { done in
                                    dispatch_async(dispatch_get_main_queue()) {
                                        expect(trace.notificationNames()).to(beEmpty())
                                        done()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}