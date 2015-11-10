import Foundation
import Swifter

func withSwifter(port: UInt16 = 8081, k: (HttpServer) throws -> ()) {
    let server = HttpServer()
    server.start(port)
    
    defer {
        server.stop()
    }
    
    NSThread.sleepForTimeInterval(0.1)
    try! k(server)
}

