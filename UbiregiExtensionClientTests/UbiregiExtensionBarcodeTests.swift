import XCTest
import Quick
import Nimble
import Swifter
@testable import UbiregiExtensionClient

class UbiregiExtensionBarcodeTests: QuickSpec {
    override func spec() {
        var client: UXCUbiregiExtension!
        
        beforeEach {
            client = UXCUbiregiExtension(hostname: "localhost", port: 8081, numericAddress: nil)
        }
        
        afterEach {
            client = nil
        }
        
        describe("#scanBarcode") {
            it("scans barcode") {
                withSwifter { server in
                    server["/scan"] = { request in .OK(.Text("1234567890")) }
                    
                    waitUntil { done in
                        client.scanBarcode { barcode in
                            expect(barcode).notTo(beNil())
                            expect(barcode).to(equal("1234567890"))
                            done()
                        }
                    }
                }
            }
            
            it("yields callback with nil if no result obtained") {
                withSwifter { server in
                    server["/scan"] = { request in .OK(.Text("")) }
                    
                    waitUntil { done in
                        client.scanBarcode { barcode in
                            expect(barcode).to(beNil())
                            done()
                        }
                    }
                }
            }

            it("yields callback with nil if timeout") {
                withSwifter { server in
                    server["/scan"] = { request in
                        NSThread.sleepForTimeInterval(1)
                        return .OK(.Text(""))
                    }
                    
                    waitUntil { done in
                        client.scanBarcode(0.5) { barcode in
                            expect(barcode).to(beNil())
                            done()
                        }
                    }
                }
            }
            
            it("keeps .Connected connectionStatus even if timeout") {
                withSwifter { server in
                    client._connectionStatus = .Connected
                    
                    server["/scan"] = { request in
                        NSThread.sleepForTimeInterval(1)
                        return .OK(.Text(""))
                    }
                    
                    waitUntil { done in
                        client.scanBarcode(0.5) { barcode in
                            expect(barcode).to(beNil())
                            done()
                        }
                    }
                    
                    expect(client.connectionStatus).to(equal(UXCConnectionStatus.Connected))
                }
            }
            
            it("keeps .hasBarcodeScanner even if timeout") {
                withSwifter { server in
                    client._connectionStatus = .Connected
                    client._hasBarcodeScanner = true
                    
                    server["/scan"] = { request in
                        NSThread.sleepForTimeInterval(1)
                        return .OK(.Text(""))
                    }
                    
                    waitUntil { done in
                        client.scanBarcode(0.5) { barcode in
                            done()
                        }
                    }
                    
                    expect(client.hasBarcodeScanner).to(beTrue())
                }
            }
            
            it("updates hasBarcodeScanner to false if 404 returned") {
                withSwifter { server in
                    server["/scan"] = { request in
                        return .NotFound
                    }
                
                    client._hasBarcodeScanner = true
                    
                    waitUntil { done in
                        client.scanBarcode { barcode in
                            done()
                        }
                    }
                    
                    expect(client.hasBarcodeScanner).to(beFalse())
                }
            }
            
            it("updates hasBarcodeScanner to true if request succeeds") {
                withSwifter { server in
                    server["/scan"] = { request in
                        return .OK(.Text("123"))
                    }
                    
                    client._hasBarcodeScanner = false
                    
                    waitUntil { done in
                        client.scanBarcode { barcode in
                            done()
                        }
                    }
                    
                    expect(client.hasBarcodeScanner).to(beTrue())
                }
            }
            
            it("keeps hasBarcodeScanner to be true when connection failed") {
                client._hasBarcodeScanner = true
                
                waitUntil { done in
                    client.scanBarcode { barcode in
                        done()
                    }
                }
                
                expect(client.hasBarcodeScanner).to(beTrue())
            }
            
            it("posts notification when barcode scanner availability changed to false") {
                withSwifter { server in
                    server["/scan"] = { request in
                        return .NotFound
                    }
                    
                    client._hasBarcodeScanner = true
                    
                    self.expectationForNotification(UbiregiExtensionDidUpdateBarcodeScannerAvailabilityNotification, object: client, handler: nil)
                    
                    waitUntil { done in
                        client.scanBarcode { barcode in
                            done()
                        }
                    }
                    
                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }
            }

            it("posts notification when barcode scanner availability changed to true") {
                withSwifter { server in
                    server["/scan"] = { request in
                        return .OK(.Text("1234567890"))
                    }
                    
                    client._hasBarcodeScanner = false
                    
                    self.expectationForNotification(UbiregiExtensionDidUpdateBarcodeScannerAvailabilityNotification, object: client, handler: nil)
                    
                    waitUntil { done in
                        client.scanBarcode { barcode in
                            done()
                        }
                    }
                    
                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }
            }
        }
    }
}
