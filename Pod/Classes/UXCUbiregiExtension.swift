import Foundation
import SMHTTPClient

public enum UXCHttpMethod: Int {
    case GET
    case POST
    case PUT
    case DELETE
}

let UbiregiExtensionDidUpdateConnectionStatusNotification = "UXCUbiregiExtensionDidUpdateConnectionStatusNotification"
let UbiregiExtensionDidUpdateStatusNotification = "UXCUbiregiExtensionDidUpdateConnectionNotification"
let UbiregiExtensionDidUpdatePrinterAvailabilityNotification = "UXCUbiregiExtensionDidUpdatePrinterAvailabilityNotification"
let UbiregiExtensionDidUpdateBarcodeScannerAvailabilityNotification = "UXCUbiregiExtensionDidUpdateBarcodeScannerAvailabilityNotification"

public class UXCUbiregiExtension: NSObject {
    public let hostname: String
    public let port: UInt

    var _connectionStatus: UXCConnectionStatus
    var _status: AnyObject?
    var _hasBarcodeScanner: Bool
    var _hasPrinter: Bool
    
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
        self._hasBarcodeScanner = false
        self._hasPrinter = false
        
        self.client = UXCAPIClient(hostname: self.hostname, port: self.port, address: address)
        self.lock = ReadWriteLock()
    }
    
    public var connectionStatus: UXCConnectionStatus {
        return self.lock.read { self._connectionStatus }
    }
    
    public var status: AnyObject? {
        return self.lock.read { self._status }
    }
    
    public func requestJSON(path: String, query: [String: String], method: UXCHttpMethod, body: AnyObject?, timeout: NSTimeInterval = 5, allowTimeout: Bool = false, callback: (UXCAPIResponse) -> ()) -> () {
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
        case .DELETE:
            m = .DELETE
        }
        
        self.client.sendRequest(path, query: query, method: m, timeout: timeout) { response in
            let lastStatus = self.connectionStatus
            
            self.lock.write {
                if response is UXCAPISuccessResponse {
                    self._connectionStatus = .Connected
                }
                
                if let response = response as? UXCAPIErrorResponse {
                    if allowTimeout && response.error.code == UXCErrorCode.Timeout.rawValue {
                        // Skip updating to error
                    } else {
                        self._connectionStatus = .Error
                    }
                }
            }
            
            if lastStatus != self.connectionStatus {
                self.postNotification(UbiregiExtensionDidUpdateConnectionStatusNotification)
            }
            
            callback(response)
        }
    }
    
    @objc public func getJSON(path: String, query: [String: String] = [:], timeout: NSTimeInterval = 5, callback: (UXCAPIResponse) -> ()) {
        self.requestJSON(path, query: query, method: .GET, body: nil, timeout: timeout, callback: callback)
    }
    
    @objc public func postJSON(path: String, json: AnyObject, timeout: NSTimeInterval = 5, callback: (UXCAPIResponse) -> ()) {
        self.requestJSON(path, query: [:], method: .POST, body: json, timeout: timeout, callback: callback)
    }
    
    @objc public func putJSON(path: String, json: AnyObject, timeout: NSTimeInterval = 5, callback: (UXCAPIResponse) -> ()) {
        self.requestJSON(path, query: [:], method: .PUT, body: json, timeout: timeout, callback: callback)
    }
    
    @objc public func deleteJSON(path: String, timeout: NSTimeInterval = 5, callback: (UXCAPIResponse) -> ()) {
        self.requestJSON(path, query: [:], method: .DELETE, body: nil, timeout: timeout, callback: callback)
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
    
    private func postNotification(name: String, userInfo: [NSObject: AnyObject]? = nil) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            NSNotificationCenter.defaultCenter().postNotificationName(name, object: self, userInfo: userInfo)
        }
    }
    
    public func updateStatus(reload: Bool = false, callback: () -> ()) {
        let timestamp = ISO8601String()
        
        self.requestJSON("/status", query: ["timestamp": timestamp, "reload": reload ? "true" : "false"], method: .GET, body: nil) { response in
            if let response = response as? UXCAPISuccessResponse {
                if response.code == 200 {
                    let newStatus = response.JSONBody
                    
                    self.lock.write {
                        self._status = newStatus
                        
                        let barcodes = (self._status?["barcodes"] as? [AnyObject]) ?? []
                        self.setHasBarcodeScanner(!barcodes.isEmpty)
                        
                        let printers = (self._status?["printers"] as? [AnyObject]) ?? []
                        self.setHasPrinter(!printers.isEmpty)
                    }
                    
                    self.postNotification(UbiregiExtensionDidUpdateStatusNotification)
                }
            }
            
            callback()
        }
    }
    
    public func scanBarcode(timeout: NSTimeInterval = 20, callback: (String?) -> ()) {
        self.requestJSON("/scan", query: [:], method: .GET, body: nil, timeout: timeout, allowTimeout: true) { response in
            let barcode: String?
            
            if let response = response as? UXCAPISuccessResponse {
                let data = response.body
                let s = NSString(data: data, encoding: NSUTF8StringEncoding)! as String
                if s.characters.isEmpty {
                    barcode = nil
                } else {
                    barcode = s
                }
                
                self.lock.write {
                    self.setHasBarcodeScanner(response.code != 404)
                }
            } else {
                barcode = nil
            }
            
            callback(barcode)
        }
    }
    
    public var hasBarcodeScanner: Bool {
        return self._hasBarcodeScanner
    }
    
    public var hasPrinter: Bool {
        return self._hasPrinter
    }
    
    func setHasBarcodeScanner(f: Bool) {
        if f != self._hasBarcodeScanner {
            self._hasBarcodeScanner = f
            self.postNotification(UbiregiExtensionDidUpdateBarcodeScannerAvailabilityNotification)
        }
    }
    
    func setHasPrinter(f: Bool) {
        if f != self._hasPrinter {
            self._hasPrinter = f
            self.postNotification(UbiregiExtensionDidUpdatePrinterAvailabilityNotification)
        }
    }
}
