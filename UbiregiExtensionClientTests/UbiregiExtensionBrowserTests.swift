import Foundation
import Quick
import Nimble
@testable import UbiregiExtensionClient

class UbiregiExtensionBrowserTests: QuickSpec {
    override func spec() {
        let extensionServiceType = "_test_extension._tcp."
        let workstationServiceType = "_test_workstation._tcp."
        
        var browser: UXCUbiregiExtensionBrowser!
        
        beforeEach {
            browser = UXCUbiregiExtensionBrowser()
            browser.delayForRetry = 0.1
            browser.extensionServiceType = extensionServiceType
            browser.workstationServiceType = workstationServiceType
            browser.workstationServicePort = 8080
        }
        
        afterEach {
            browser.stop()
            browser = nil
        }
        
        context("UbiregiExtension service type discovery") {
            it("finds out extension") {
                self.publishService(extensionServiceType, port: 8081) {
                    withSwifter(8081) { server in
                        server["/status"] = { request in .OK(.Json([])) }
                        
                        let trace = NotificationTrace()
                        trace.observeNotification(UXCConstants.UbiregiExtensionBrowserDidFindExtensionNotification, object: browser)
                        
                        browser.start()
                        
                        self.runLoopFor(2)
                        
                        expect(trace.notificationNames()).to(equal([UXCConstants.UbiregiExtensionBrowserDidFindExtensionNotification]))
                    }
                }
            }
        }
        
        context("Workstatiion service type discovery") {
            it("finds out extension") {
                self.publishService(workstationServiceType, port: 22) {
                    withSwifter(8080) { server in
                        server["/status"] = { request in .OK(.Json([])) }
                        
                        let trace = NotificationTrace()
                        trace.observeNotification(UXCConstants.UbiregiExtensionBrowserDidFindExtensionNotification, object: browser)
                        
                        browser.start()
                        
                        self.runLoopFor(2)
                        
                        expect(trace.notificationNames()).to(equal([UXCConstants.UbiregiExtensionBrowserDidFindExtensionNotification]))
                    }
                }
            }
        }
        
        describe("It confirms if the Bonjour service is reachable") {
            it("skips if found service is unreachable") {
                self.publishService(extensionServiceType, port: 8081) {
                    let trace = NotificationTrace()
                    trace.observeNotification(UXCConstants.UbiregiExtensionBrowserDidFindExtensionNotification, object: browser)
                    
                    browser.start()
                    
                    self.runLoopFor(3)
                    
                    expect(trace.notifications).to(beEmpty())
                }
            }
            
            it("skips if found service does not looks like UbiregiExtension") {
                self.publishService(extensionServiceType, port: 8081) {
                    withSwifter(8081) { server in
                        server["/status"] = { request in .OK(.Text("test message")) }
                        
                        let trace = NotificationTrace()
                        trace.observeNotification(UXCConstants.UbiregiExtensionBrowserDidFindExtensionNotification, object: browser)
                        
                        browser.start()
                        
                        self.runLoopFor(3)
                        
                        expect(trace.notifications).to(beEmpty())
                    }
                }
            }
        }
    }
    
    func runLoopFor(seconds: NSTimeInterval) {
        let date = NSDate().dateByAddingTimeInterval(seconds)
        NSRunLoop.currentRunLoop().runUntilDate(date)
    }
    
    func publishService(type: String, port: UInt64, k: () -> ()) {
        let service = NSNetService(domain: "local.", type: type, name: "Test Host", port: Int32(port))
        service.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        service.publish()
        
        k()
        
        service.stop()
    }
}
