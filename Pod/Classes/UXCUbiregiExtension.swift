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

    var _connectionStatus: UXCConnectionStatus
    var _status: AnyObject?
    
    let client: UXCAPIClient
    let lock: ReadWriteLock
    
    public init(hostname: String, port: UInt, numericAddress: String?) {
        self.hostname = hostname
        self.port = port
        
        var address: sockaddr?
        
        if let addr = numericAddress {
            let resolver = NameResolver(hostname: addr, port: port)
            resolver.run()
            
            address = resolver.IPv4Results.first ?? resolver.IPv6Results.first
        }
        
        self._connectionStatus = .Initialized
        self._status = nil
        
        self.client = UXCAPIClient(hostname: self.hostname, port: self.port, address: address)
        self.lock = ReadWriteLock()
    }
    
    public var connectionStatus: UXCConnectionStatus {
        return self.lock.read { self._connectionStatus }
    }
    
    public var status: AnyObject? {
        return self.lock.read { self._status }
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
            self.lock.write {
                if response is UXCAPISuccessResponse {
                    self._connectionStatus = .Connected
                } else {
                    self._connectionStatus = .Error
                }
            }
            
            callback(response)
        }
    }
    
    public var version: UXCVersion? {
        if let status = self.status as? [String: AnyObject] {
            if let v = status["version"] {
                return UXCVersion(string: v as! String)
            } else {
                return UXCVersion(string: "1.0.0")
            }
        } else {
            return nil
        }
    }
    
    public func updateStatus(reload: Bool = false, callback: () -> ()) {
        let timestamp = ISO8601String()
        
        self.requestJSON("/status", query: ["timestamp": timestamp, "reload": reload ? "true" : "false"], method: .GET, body: nil) { response in
            if let response = response as? UXCAPISuccessResponse {
                if response.code == 200 {
                    self.lock.write {
                        self._status = response.JSONBody
                    }
                }
            }
            
            callback()
        }
    }
}