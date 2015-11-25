import Foundation

let UbiregiExtensionServiceType = "_ubiregiex._tcp."
let WorkstationServiceType = "_workstation._tcp."

@objc public class UXCUbiregiExtensionBrowser: NSObject, NSNetServiceBrowserDelegate, NSNetServiceDelegate {
    let extensionBrowser: NSNetServiceBrowser
    let workstationBrowser: NSNetServiceBrowser
    var resolvingServices: Set<NSNetService>!
    let queue: dispatch_queue_t
    var delayForRetry: Double = 1
    var maxRetry: Int = 5
    var extensionServiceType: String
    var workstationServiceType: String
    var workstationServicePort: Int = 80
    
    override public init() {
        self.extensionBrowser = NSNetServiceBrowser()
        self.workstationBrowser = NSNetServiceBrowser()
        self.queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        self.extensionServiceType = UbiregiExtensionServiceType
        self.workstationServiceType = WorkstationServiceType
        
        super.init()

        self.extensionBrowser.delegate = self
        self.workstationBrowser.delegate = self
    }
    
    /**
     */
    public func start() {
        self.resolvingServices = Set()
        
        self.extensionBrowser.searchForServicesOfType(self.extensionServiceType, inDomain: "local.")
        self.workstationBrowser.searchForServicesOfType(self.workstationServiceType, inDomain: "local.")
    }
    
    /**
     */
    public func stop() {
        self.extensionBrowser.stop()
        self.workstationBrowser.stop()
        
        self.resolvingServices = nil
    }
    
    // MARK:-
    
    public func netServiceBrowser(browser: NSNetServiceBrowser, didFindService service: NSNetService, moreComing: Bool) {
        guard browser == self.workstationBrowser || browser == self.extensionBrowser else { return }
        
        self.resolvingServices.insert(service)
        service.delegate = self
        service.resolveWithTimeout(5)
    }
    
    // MARK: -
    
    public func netServiceDidResolveAddress(sender: NSNetService) {
        guard self.resolvingServices.contains(sender) else { return }
        
        self.resolvingServices.remove(sender)
        
        self.testIfNetServiceIsExtension(sender) { (host, port) in
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName(
                    UXCConstants.UbiregiExtensionBrowserDidFindExtensionNotification,
                    object: self,
                    userInfo: [
                        UXCConstants.UbiregiExtensionBrowserExtensionHostKey: host,
                        UXCConstants.UbiregiExtensionBrowserExtensionPortKey: port
                    ]
                )
            }
        }
    }
    
    public func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
        guard self.resolvingServices.contains(sender) else { return }
        self.resolvingServices.remove(sender)
    }
    
    // Mark: -
    
    func testIfNetServiceIsExtension(service: NSNetService, callback: (String, Int) -> ()) {
        let host = service.hostName!.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "."))
        let port = service.type == self.workstationServiceType ? self.workstationServicePort : service.port
        let ext = UXCUbiregiExtension(hostname: host, port: UInt(port), numericAddress: nil)
        self.tryExtension(ext) {
            callback(host, port)
        }
    }
    
    func tryExtension(ext: UXCUbiregiExtension, count: Int = 0, callback: () -> ()) {
        ext.updateStatus {
            if ext.connectionStatus == .Connected && ext.status != nil {
                callback()
            } else {
                if count < self.maxRetry {
                    let when = dispatch_time(DISPATCH_TIME_NOW, Int64(self.delayForRetry * Double(NSEC_PER_SEC)))
                    dispatch_after(when, self.queue) {
                        self.tryExtension(ext, count: count+1, callback: callback)
                    }
                }
            }
        }
    }
}
