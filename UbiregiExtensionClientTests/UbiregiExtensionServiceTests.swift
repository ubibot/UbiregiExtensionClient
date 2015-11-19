import XCTest
import Quick
import Nimble
import Swifter
@testable import UbiregiExtensionClient

class UbiregiExtensionServiceTests: QuickSpec {
    override func spec() {
        var service: UXCUbiregiExtensionService!
        
        beforeEach {
            service = UXCUbiregiExtensionService()
        }
        
        afterEach {
            service = nil
        }
        
        let ext = UXCUbiregiExtension(hostname: "localhost", port: 8080, numericAddress: nil)
        
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
                beforeEach {
                    // Update connection status every seconds
                    service.updateStatusInterval = 0.1
                    // Set non main queue for notification
                    service.notificationQueue = dispatch_queue_create("com.ubiregi.UbiregiExtensionClient.test", nil)
                }
                
                let e1 = UXCUbiregiExtension(hostname: "localhost", port: 8080, numericAddress: nil)
                let e2 = UXCUbiregiExtension(hostname: "localhost", port: 8081, numericAddress: nil)
                
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
                    service.addExtension(e1)
                    
                    waitFor(2, message: "Wait for connection status got .Error") {
                        service.connectionStatus == .Error
                    }
                    
                    let observer = NotificationTrace()
                    NSNotificationCenter.defaultCenter().addObserver(observer, selector: "didReceiveNotification:", name: UXCConstants.UbiregiExtensionServiceDidUpdateConnectionStatusNotification, object: service)
                    
                    withSwifter(8080) { server in
                        server["/status"] = returnJSON(["version": "1.2.3"])
                        
                        service.updateStatus()
                        
                        waitUntil(timeout: 3) {
                            NSThread.sleepForTimeInterval(1)
                            $0()
                        }
                        
                        let connectionNotifications = observer.notifications.filter {
                            let newStatus = $0.userInfo!["newConnectionStatus"] as! Int
                            let oldStatus = $0.userInfo!["oldConnectionStatus"] as! Int
                            
                            return oldStatus == UXCConnectionStatus.Error.rawValue && newStatus == UXCConnectionStatus.Connected.rawValue
                        }
                                                
                        expect(connectionNotifications.count).to(equal(1))
                    }
                }
            }
        }
    }
}