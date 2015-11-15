import XCTest
import Quick
import Nimble
import SMHTTPClient
import Swifter
@testable import UbiregiExtensionClient

class APIClientTests: QuickSpec {
    var server: HttpServer?
    
    override func spec() {
        describe("#sendRequest") {
            describe("result callback") {
                it("invokes callback with UXCAPISuccessResult if API call succeeds") {
                    withSwifter { (server: HttpServer) in
                        waitUntil { done in
                            server["/test"] = { request in HttpResponse.OK(HttpResponseBody.JSON([] as AnyObject)) }
                            
                            let request = UXCAPIClient(hostname: "localhost", port: 8081, address: nil)
                            request.sendRequest("/test", query: [:], method: .GET, timeout: 3) { response in
                                expect(response is UXCAPISuccessResponse).to(beTrue())
                                done()
                            }
                        }
                    }
                }
                
                it("invokes callback with UXCAPIErrorResult if API call timeouts") {
                    withSwifter { (server: HttpServer) in
                        waitUntil(timeout: 5) { done in
                            server["/test"] = { request in
                                NSThread.sleepForTimeInterval(5)
                                return HttpResponse.OK(HttpResponseBody.JSON([] as AnyObject))
                            }
                            
                            let request = UXCAPIClient(hostname: "localhost", port: 8081, address: nil)
                            request.sendRequest("/test", query: [:], method: .GET, timeout: 2) { response in
                                let res = response as! UXCAPIErrorResponse
                                expect(res.error.code).to(equal(UXCErrorCode.Timeout.rawValue))
                                
                                done()
                            }
                        }
                    }
                }
                
                it("invokes callback with UXCAPIErrorResult if API call failed by connection reset") {
                    withSwifter { (server: HttpServer) in
                        waitUntil { done in
                            server["/test"] = { request in
                                server.stop()
                                return HttpResponse.OK(HttpResponseBody.JSON([] as AnyObject))
                            }
                            
                            let request = UXCAPIClient(hostname: "localhost", port: 8081, address: nil)
                            request.sendRequest("/test", query: [:], method: .GET, timeout: 2) { response in
                                let res = response as! UXCAPIErrorResponse
                                expect(res.error.code).to(equal(UXCErrorCode.ConnectionFailure.rawValue))
                                
                                done()
                            }
                        }
                    }
                }
                
                it("invokes callback with UXCAPIErrorResult if connection fails") {
                    waitUntil { done in
                        let request = UXCAPIClient(hostname: "localhost", port: 8081, address: nil)
                        request.sendRequest("/test", query: [:], method: .GET, timeout: 2) { response in
                            let res = response as! UXCAPIErrorResponse
                            expect(res.error.code).to(equal(UXCErrorCode.ConnectionFailure.rawValue))
                            
                            done()
                        }
                    }
                }
                
                it("invokes callback with UXCAPIErrorResult if name resolution fails") {
                    waitUntil(timeout: 3) { done in
                        let request = UXCAPIClient(hostname: "no-such-host.local", port: 8081, address: nil)
                        request.sendRequest("/test", query: [:], method: .GET, timeout: 2) { response in
                            let res = response as! UXCAPIErrorResponse
                            expect(res.error.code).to(equal(UXCErrorCode.NameResolution.rawValue))
                            
                            done()
                        }
                    }
                }
            }
            
            describe("request header") {
                it("sends Host header if host name resolved") {
                    withSwifter { server in
                        waitUntil { done in
                            server["/test"] = { (request: Swifter.HttpRequest) in
                                return HttpResponse.OK(HttpResponseBody.JSON(request.headers))
                            }
                            
                            let request = UXCAPIClient(hostname: "localhost", port: 8081, address: nil)
                            request.sendRequest("/test", query: [:], method: .GET, timeout: 2) { response in
                                let res = response as! UXCAPISuccessResponse
                                // Swifter downcase request header name
                                expect(res.JSONBody!["host"]).to(equal("localhost"))
                                
                                done()
                            }
                        }
                    }
                }
                
                it("does not send Host header if host name failed to resolve and uses cached address") {
                    withSwifter { server in
                        waitUntil(timeout: 3) { done in
                            server["/test"] = { (request: Swifter.HttpRequest) in
                                return HttpResponse.OK(HttpResponseBody.JSON(request.headers))
                            }
                            
                            let resolver = NameResolver(hostname: "localhost", port: 8081)
                            resolver.run()
                            let address = resolver.IPv4Results.first!
                            
                            let request = UXCAPIClient(hostname: "no-such-host.soutaro.com", port: 8081, address: address)
                            request.sendRequest("/test", query: [:], method: .GET, timeout: 2) { response in
                                let res = response as! UXCAPISuccessResponse
                                // Swifter downcase request header name
                                expect(res.JSONBody!["host"]).to(beNil())
                                
                                done()
                            }
                        }
                    }
                }
            }
        }
        
        describe("#resolveAddress") {
            context("name resolution succeeded") {
                it("caches name resolution result if succeeds") {
                    let request = UXCAPIClient(hostname: "localhost", port: 80, address: nil)
                    
                    waitUntil { done in
                        request.resolveAddress(1) { result in
                            switch result {
                            case .ResolvedToAddress(let addr, true):
                                expect(numericAddress(request.address!)).to(equal(numericAddress(addr)))
                            default:
                                XCTAssert(false)
                            }
                            done()
                        }
                    }
                }
                
                it("updates sockaddr cache if successfuly resolved") {
                    let resolver = NameResolver(hostname: "0.0.0.0", port: 80)
                    resolver.run()
                    let address = resolver.results.first!
                    
                    let request = UXCAPIClient(hostname: "localhost", port: 80, address: address)
                    
                    waitUntil { done in
                        request.resolveAddress(0.5) { result in
                            switch result {
                            case .ResolvedToAddress(let addr, true):
                                expect(numericAddress(request.address!)).notTo(equal(numericAddress(address)))
                                expect(numericAddress(request.address!)).to(equal(numericAddress(addr)))
                            default:
                                XCTAssert(false)
                            }
                            done()
                        }
                    }
                }
                
            }
            
            context("name resolution timed out") {
                it("uses cached sockaddr if name resolution timed out") {
                    let resolver = NameResolver(hostname: "localhost", port: 80)
                    resolver.run()
                    let address = resolver.IPv4Results.first!
                    
                    let request = UXCAPIClient(hostname: "no-such-host.local", port: 80, address: address)
                    
                    waitUntil { done in
                        // Resolving non existing .local host takes ~5secs to fail.
                        // The name resolution will result in timeout.
                        request.resolveAddress(0.5) { result in
                            switch result {
                            case .ResolvedToAddress(let addr, false):
                                expect(numericAddress(addr)).to(equal(numericAddress(address)))
                            default:
                                XCTAssert(false)
                            }
                            
                            done()
                        }
                    }
                }
            }
            
            context("name resolution failed") {
                it("notifies error if no sockaddr is cached") {
                    let request = UXCAPIClient(hostname: "no-such-host", port: 80, address: nil)
                    
                    waitUntil { done in
                        request.resolveAddress(0.5) { result in
                            switch result {
                            case .Error:
                                expect(request.address).to(beNil())
                            default:
                                XCTAssert(false)
                            }
                            
                            done()
                        }
                    }
                }
                
                it("uses cached sockaddr if present") {
                    let resolver = NameResolver(hostname: "localhost", port: 80)
                    resolver.run()
                    let address = resolver.IPv4Results.first!
                    
                    let request = UXCAPIClient(hostname: "no-such-host", port: 80, address: address)
                    
                    waitUntil { done in
                        request.resolveAddress(0.5) { result in
                            switch result {
                            case .ResolvedToAddress(let addr, false):
                                expect(numericAddress(addr)).to(equal(numericAddress(address)))
                            default:
                                XCTAssert(false)
                            }
                            
                            done()
                        }
                    }
                }
            }
        }
    }
}