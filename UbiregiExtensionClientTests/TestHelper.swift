import Foundation
import Swifter

func withSwifter(port: UInt16 = 8081, k: (HttpServer) throws -> ()) {
    let server = HttpServer()
    server.start(port)
    
    defer {
        server.stop()
    }
    
    NSThread.sleepForTimeInterval(0.3)
    try! k(server)
}

func dictionary(pairs: [(String, String)]) -> [String: String] {
    var h: [String: String] = [:]
    
    for p in pairs {
        h[p.0] = p.1
    }
    
    return h
}