import XCTest
import Quick
import Nimble
import Swifter
@testable import UbiregiExtensionClient

class UbiregiExtensionServiceTests: QuickSpec {
    override func spec() {
        var service: UXCUbiregiExtensionService!
        var ext: UXCUbiregiExtension!
        
        beforeEach {
            service = UXCUbiregiExtensionService()
            ext = UXCUbiregiExtension(hostname: "localhost", port: 8080, numericAddress: nil)
        }
        
        afterEach {
            service = nil
            ext = nil
        }
        
        describe("addExtension") {
            it("adds extension") {
                service.addExtension(ext)
                
                expect(service.extensions).to(equal([ext]))
            }
            
            it("ignores already added extension") {
                service.addExtension(ext)
                service.addExtension(ext)
                
                expect(service.extensions).to(equal([ext]))
            }
        }
        
        describe("removeExtension") {
            beforeEach {
                service.addExtension(ext)
            }
            
            it("removes extension") {
                service.removeExtension(ext)
                
                expect(service.extensions).to(beEmpty())
            }
            
            it("does nothing if not registered extension is given") {
                let e2 = UXCUbiregiExtension(hostname: "localhost", port: 8081, numericAddress: nil)
                
                service.removeExtension(e2)
                
                expect(service.extensions).to(equal([ext]))
            }
        }
        
        describe("findExtension") {
            beforeEach {
                service.addExtension(ext)
            }
            
            it("finds extension") {
                let e = service.findExtensionForHostname("localhost", port: 8080)
                
                expect(e).notTo(beNil())
                expect(e).to(equal(ext))
            }
            
            it("returns nil if no extension found for hostname and port") {
                let e = service.findExtensionForHostname("google.com", port: 80)
                
                expect(e).to(beNil())
            }
        }
        
        describe("status refresh") {
            describe("updateStatus") {
                var e1: UXCUbiregiExtension!
                var e2: UXCUbiregiExtension!
                
                beforeEach {
                    // Update connection status every seconds
                    service.updateStatusInterval = 0.1
                    // Set non main queue for notification
                    service.notificationQueue = dispatch_queue_create("com.ubiregi.UbiregiExtensionClient.test", nil)
                    
                    e1 = UXCUbiregiExtension(hostname: "localhost", port: 8080, numericAddress: nil)
                    e2 = UXCUbiregiExtension(hostname: "localhost", port: 8081, numericAddress: nil)
                }
                
                afterEach {
                    e1 = nil
                    e2 = nil
                }
                
                it("updates connection status of all extensions") {
                    expect(service.connectionStatus).to(equal(UXCConnectionStatus.Initialized))
                    
                    withSwifter(8080) { s1 in
                        s1["/status"] = returnJSON(["version": "1.2.3"])
                        
                        withSwifter(8081) { s2 in
                            s2["/status"] = returnJSON(["version": "2.3.4"])
                            
                            service.addExtension(e1)
                            service.addExtension(e2)
                            
                            waitFor(3) {
                                service.connectionStatus == .Connected
                            }
                        }
                    }
                }
                
                it("posts notification on connection status update") {
                    service.periodicalUpdateStatusEnabled = false
                    
                    service.addExtension(e1)
                    
                    waitFor(2, message: "Wait for connection status got .Error") {
                        service.connectionStatus == .Error
                    }
                    
                    let observer = NotificationTrace()
                    NSNotificationCenter.defaultCenter().addObserver(observer, selector: "didReceiveNotification:", name: UXCConstants.UbiregiExtensionServiceDidUpdateConnectionStatusNotification, object: service)
                    
                    withSwifter(8080) { server in
                        server["/status"] = returnJSON(["version": "1.2.3"])
                        
                        service.updateStatus()
                        
                        NSThread.sleepForTimeInterval(1)
                    
                        let connectionNotifications = observer.notifications.filter {
                            let newStatus = $0.userInfo!["newConnectionStatus"] as! Int
                            let oldStatus = $0.userInfo!["oldConnectionStatus"] as! Int
                            
                            return oldStatus == UXCConnectionStatus.Error.rawValue && newStatus == UXCConnectionStatus.Connected.rawValue
                        }
                                                
                        expect(connectionNotifications.count).to(equal(1))
                    }
                }
                
                it("makes next retry soon if connection failed") {
                    service.periodicalUpdateStatusEnabled = false
                    service.updateStatusInterval = 120
                    service._connectionStatus = .Connected
                    
                    // Wait for already running updateStatus to finish
                    NSThread.sleepForTimeInterval(0.3)

                    // Use _extensions directly, not addExtension, to skip updateStatus call on extension addition
                    service._extensions.append(e1)
                    
                    // Kick connection failure recovery
                    NSNotificationCenter.defaultCenter().postNotificationName(UbiregiExtensionDidUpdateConnectionStatusNotification, object: e1)
                    
                    withSwifter(8080) { server in
                        self.expectationForNotification(UXCConstants.UbiregiExtensionServiceDidUpdateConnectionStatusNotification, object: service) { notification in
                            service.connectionStatus == UXCConnectionStatus.Connected
                        }
                        
                        server["/status"] = returnJSON(["version": "3.4.5"])
                        
                        self.waitForExpectationsWithTimeout(3.0, handler: nil)
                    }
                }
            }
        }
        
        describe("barcode scanning") {
            var e1: UXCUbiregiExtension!
            
            beforeEach {
                // Update connection status every seconds
                service.updateStatusInterval = 0.1
                // Set non main queue for notification
                service.notificationQueue = dispatch_queue_create("com.ubiregi.UbiregiExtensionClient.test", nil)
                
                e1 = UXCUbiregiExtension(hostname: "localhost", port: 8081, numericAddress: nil)
            }
            
            afterEach {
                e1 = nil
            }
            
            let responseWithDevices = { (request: HttpRequest) in
                HttpResponse.OK(
                    .Json(
                        [
                            "version": "1.2.3",
                            "product_version": "October, 2015",
                            "release": "1-3",
                            "printers": ["present"],
                            "barcodes": ["present"]
                        ]
                    )
                )
            }
            
            it("posts a notification on barcode scan") {
                withSwifter { server in
                    server["/status"] = responseWithDevices
                    server["/scan"] = { request in .OK(.Text("123456")) }
                    
                    self.expectationForNotification(UXCConstants.UbiregiExtensionServiceDidScanBarcodeNotification, object: service, handler: nil)
                    
                    service.addExtension(e1)
                    
                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }
            }
        }
    }
}