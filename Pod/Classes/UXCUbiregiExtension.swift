import Foundation
import SMHTTPClient

public enum UXCHttpMethod: Int {
    case GET
    case POST
    case PUT
}

public class UXCUbiregiExtension: NSObject {
    public let hostname: String
    public let port: UInt

    let client: UXCAPIClient
    var _status: UXCExtensionStatus
    let queue: dispatch_queue_t
    
    public init(hostname: String, port: UInt, numericAddress: String?) {
        self.hostname = hostname
        self.port = port
        
        var address: sockaddr?
        
        if let addr = numericAddress {
            let resolver = NameResolver(hostname: addr, port: port)
            resolver.run()
            
            address = !resolver.IPv4Results.isEmpty ? resolver.IPv4Results.first : resolver.IPv6Results.first
        }
        
        self.client = UXCAPIClient(hostname: self.hostname, port: self.port, address: address)
        
        self._status = .Initialized
        
        self.queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    }
    
    private func withReadLock<T>(proc:() -> T) -> T {
        var result: T? = nil
        dispatch_sync(self.queue) {
            result = proc()
        }
        return result!
    }
    
    private func withWriteLock<T>(proc: () -> T) -> T {
        var result: T? = nil
        dispatch_barrier_sync(self.queue) {
            result = proc()
        }
        return result!
    }
    
    public var status: UXCExtensionStatus {
        return self.withReadLock { self._status }
    }
    
    public func requestJSON(path: String, query: [String: String], method: UXCHttpMethod, body: AnyObject?, timeout: NSTimeInterval = 5, callback: (UXCAPIResponse) -> ()) -> () {
        let bodyData: NSData
        if let b = body {
            bodyData = try! NSJSONSerialization.dataWithJSONObject(b, options: NSJSONWritingOptions.PrettyPrinted)
        } else {
            bodyData = NSData()
        }
        
        let m: HttpMethod
        switch method {
        case .GET:
            m = .GET
        case .POST:
            m = .POST(bodyData)
        case .PUT:
            m = .PUT(bodyData)
        }
        
        self.client.sendRequest(path, query: query, method: m, timeout: timeout) { response in
            self.withWriteLock {
                if response is UXCAPISuccessResponse {
                    self._status = .Connected
                } else {
                    self._status = .Error
                }
            }
            
            callback(response)
        }
    }
}