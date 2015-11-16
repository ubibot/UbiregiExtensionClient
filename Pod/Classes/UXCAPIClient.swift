import Foundation
import SMHTTPClient

internal enum UXCNameResolutionResult {
    case ResolvedToAddress(sockaddr, Bool)
    case NotFound
    case Error
}

internal class UXCAPIClient {
    let hostname: String
    let port: UInt
    var _address: sockaddr?
    let _queue: dispatch_queue_t
    
    init(hostname: String, port: UInt, address: sockaddr?) {
        self.hostname = hostname
        self.port = port
        
        self._address = address
        self._queue = dispatch_queue_create("com.ubiregi.UXCAPIClient.queue", nil)
    }
    
    func async(block: dispatch_block_t) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block)
    }
    
    var address: sockaddr? {
        get {
            var a: sockaddr?
            dispatch_sync(self._queue) { a = self._address }
            return a
        }
        
        set(a) {
            dispatch_sync(self._queue) { self._address = a }
        }
    }
    
    func after(delay: NSTimeInterval, block: dispatch_block_t) {
        var d = delay
        if d <= 0 {
            d = 0.1
        }
        let when = dispatch_time(DISPATCH_TIME_NOW, Int64(d * Double(NSEC_PER_SEC)))
        dispatch_after(when, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            block()
        }
    }
    
    var defaultQueue: dispatch_queue_t {
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    }
    
    func sendRequest(path: String, query: [String: String], method: HttpMethod, timeout: NSTimeInterval, callback: (UXCAPIResponse) -> ()) {
        let startedAt = NSDate()
        
        async {
            self.resolveAddress(1) { result in
                switch result {
                case .ResolvedToAddress(let addr, let resolved):
                    let request = HttpRequest(address: addr, path: self.pathWithQuery(path, query: query), method: method, header: self.defaultHeader(resolved, method: method))
                    
                    self.after(timeout - NSDate().timeIntervalSinceDate(startedAt)) {
                        request.abort()
                    }
                    
                    request.run()
                    
                    switch request.status {
                    case .Completed(let code, let header, let data):
                        var h: [String: String] = [:]
                        for (k,v) in header {
                            h[k] = v
                        }
                        callback(UXCAPISuccessResponse(code: code, header: h, body: data))
                    case .Aborted:
                        let error = NSError(domain: UXCConstants.ErrorDomain, code: UXCErrorCode.Timeout.rawValue, userInfo: nil)
                        callback(UXCAPIErrorResponse(error: error))
                    default:
                        let error = NSError(domain: UXCConstants.ErrorDomain, code: UXCErrorCode.ConnectionFailure.rawValue, userInfo: nil)
                        callback(UXCAPIErrorResponse(error: error))
                    }
                default:
                    let error = NSError(domain: UXCConstants.ErrorDomain, code: UXCErrorCode.NameResolution.rawValue, userInfo: nil)
                    callback(UXCAPIErrorResponse(error: error))
                }
            }
        }
    }
    
    func pathWithQuery(path: String, query: [String: String]) -> String {
        if query.isEmpty {
            return path
        } else {
            let q = try! query.map { (key, value) throws -> String in
                let escaped = value.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
                return "\(key)=\(escaped)"
            }.joinWithSeparator("&")
            
            return path + "?" + q
        }
    }
    
    func defaultHeader(resolved: Bool, method: HttpMethod) -> [(String, String)] {
        var h = [
            ("Connection", "close"),
            ("Content-Type", "application/json")
        ]
        
        if resolved {
            h.append(("Host", self.hostname))
        }
        
        switch method {
        case .PATCH(let data):
            h.append(("Content-Length", String(data.length)))
        case .POST(let data):
            h.append(("Content-Length", String(data.length)))
        case .PUT(let data):
            h.append(("Content-Length", String(data.length)))
        default: break
        }
        
        return h
    }
    
    func resolveAddress(timeout: NSTimeInterval, callback: (UXCNameResolutionResult) -> ()) {
        let resolver = NameResolver(hostname: self.hostname, port: self.port)
        
        after(timeout) {
            resolver.abort()
        }
        
        resolver.run()
        
        switch resolver.status {
        case .Resolved:
            // resolver.results can not be empty, if successfuly resolved
            // Prefere IPv4 address
            let address = (!resolver.IPv4Results.isEmpty ? resolver.IPv4Results : resolver.IPv6Results).first!
            // Save sockaddr as cache
            self.address = address
            callback(.ResolvedToAddress(address, true))
        case .Aborted:
            // Use cached address since name resolution failed
            if let addr = self.address {
                callback(.ResolvedToAddress(addr, false))
            } else {
                callback(.NotFound)
            }
        default:
            if let addr = self.address {
                callback(.ResolvedToAddress(addr, false))
            } else {
                callback(.Error)
            }
        }
    }
}