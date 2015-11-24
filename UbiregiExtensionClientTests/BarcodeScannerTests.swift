import Foundation
import Quick
import Nimble
import Swifter
@testable import UbiregiExtensionClient

class BarcodeScannerTests: QuickSpec {
    override func spec() {
        var ext: UXCUbiregiExtension!
        
        beforeEach {
            ext = UXCUbiregiExtension(hostname: "localhost", port: 8081, numericAddress: nil)
        }
        
        afterEach {
            ext = nil
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
        
        let responseWithoutDevices = { (request: HttpRequest) in
            HttpResponse.OK(
                .Json(
                    [
                        "version": "1.2.3",
                        "product_version": "October, 2015",
                        "release": "1-3",
                        "printers": [],
                        "barcodes": []
                    ]
                )
            )
        }
        
        describe("scanning") {
            it("scans") {
                withSwifter { service in
                    service["/status"] = responseWithDevices
                    service["/scan"] = { request in .OK(.Text("123456")) }
                    
                    let scanner = UXCBarcodeScanner(ext: ext)
                    
                    let trace = NotificationTrace()
                    trace.observeNotification(BarcodeScannerDidScanBarcodeNotification, object: scanner)
                    
                    NSThread.sleepForTimeInterval(0.5)
                    
                    expect(trace.notifications).notTo(beEmpty())
                    for n in trace.notifications {
                        let barcode = n.userInfo![BarcodeScannerScanedBarcodeKey] as! String
                        expect(barcode).to(equal("123456"))
                    }
                }
            }
            
            it("does not try to scan if there is no barcode scanner") {
                withSwifter { service in
                    service["/status"] = responseWithoutDevices
                    service["/scan"] = { request in .NotFound }
                    
                    let scanner = UXCBarcodeScanner(ext: ext)
                    
                    waitUntil { done in
                        ext.updateStatus {
                            done()
                        }
                    }
                    
                    expect(ext.hasBarcodeScanner).to(beFalse())
                    expect(scanner.isIdle).to(beTrue())
                    
                    let trace = NotificationTrace()
                    trace.observeNotification(BarcodeScannerDidScanBarcodeNotification, object: scanner)
                    
                    NSThread.sleepForTimeInterval(0.5)
                    
                    expect(trace.notifications).to(beEmpty())
                }
            }
            
            it("starts scanning once barcode scanner is detected") {
                withSwifter { service in
                    ext._hasBarcodeScanner = false
                    
                    let scanner = UXCBarcodeScanner(ext: ext)
                    scanner.isIdle = true
                    
                    service["/status"] = responseWithDevices
                    service["/scan"] = { request in .OK(.Text("123456")) }
                    
                    waitUntil { done in
                        ext.updateStatus {
                            done()
                        }
                    }
                    
                    let trace = NotificationTrace()
                    trace.observeNotification(BarcodeScannerDidScanBarcodeNotification, object: scanner)
                    
                    NSThread.sleepForTimeInterval(0.5)
                    
                    expect(trace.notifications).notTo(beEmpty())
                    for n in trace.notifications {
                        let barcode = n.userInfo![BarcodeScannerScanedBarcodeKey] as! String
                        expect(barcode).to(equal("123456"))
                    }
                }
            }
        }
    }
}
