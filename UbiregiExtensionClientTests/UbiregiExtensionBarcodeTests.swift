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
        
        describe("#scanBarcode") {
            it("scans barcode") {
                withSwifter { server in
                    server["/scan"] = { request in .OK(.STRING("1234567890")) }
                    
                    waitUntil { done in
                        client.scanBarcode { barcode in
                            expect(barcode).notTo(beNil())
                            expect(barcode!).to(equal("1234567890"))
                            done()
                        }
                    }
                }
            }
            
            it("yields callback with nil if no result obtained") {
                withSwifter { server in
                    server["/scan"] = { request in .OK(.STRING("")) }
                    
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
                        return .OK(.STRING(""))
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
                        return .OK(.STRING(""))
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
        }
    }
}
