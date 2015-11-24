import Foundation

public class UXCUbiregiExtensionService: NSObject {
    var _extensions: [UXCUbiregiExtension]
    var _barcodeScanners: [UXCUbiregiExtension: UXCBarcodeScanner]
    var _connectionStatus: UXCConnectionStatus
    var _isPrinterAvailable: Bool
    var _isBarcodeScannerAvailable: Bool
    public var updateStatusInterval: NSTimeInterval = 30
    var notificationQueue: dispatch_queue_t
    
    let lock: ReadWriteLock
    
    override public init() {
        self._extensions = []
        self._barcodeScanners = [:]
        self.lock = ReadWriteLock()
        self._connectionStatus = .Initialized
        self._isPrinterAvailable = false
        self._isBarcodeScannerAvailable = false
        self.notificationQueue = dispatch_get_main_queue()
        
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "connectionStatusDidUpdate:", name: UbiregiExtensionDidUpdateConnectionStatusNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "statusDidUpdate:", name: UbiregiExtensionDidUpdateStatusNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didScanBarcode:", name: BarcodeScannerDidScanBarcodeNotification, object: nil)
        
        weak var this = self
        let updateStatusQueue = dispatch_queue_create("com.ubiregi.UXCUbiregiExtensionService.updateStatus", nil)
        
        dispatch_async(updateStatusQueue) {
            while this != nil {
                if this?.updateStatusInterval > 0 {
                    this?.updateStatus()
                }
                let interval = this?.updateStatusInterval ?? 0
                NSThread.sleepForTimeInterval(interval)
            }
        }
    }
    
    public var extensions: [UXCUbiregiExtension] {
        return self.lock.read { self._extensions }
    }
    
    public var connectionStatus: UXCConnectionStatus {
        return self._connectionStatus
    }
    
    public var isPrinterAvailable: Bool {
        return self._isPrinterAvailable
    }
    
    public var isBarcodeScannerAvailable: Bool {
        return self._isBarcodeScannerAvailable
    }
    
    public func addExtension(ext: UXCUbiregiExtension) {
        self.lock.write {
            if !self._extensions.contains(ext) {
                self._extensions.append(ext)
                self._barcodeScanners[ext] = UXCBarcodeScanner(ext: ext)
            }
        }
        
        self.updateStatus()
        self.updateDeviceAvailability()
    }
    
    public func removeExtension(ext: UXCUbiregiExtension) {
        self.lock.write {
            if let index = self._extensions.indexOf(ext) {
                self._extensions.removeAtIndex(index)
                self._barcodeScanners.removeAtIndex(self._barcodeScanners.indexForKey(ext)!)
            }
        }
        
        self.updateStatus()
        self.updateConnectionStatus()
        self.updateDeviceAvailability()
    }
    
    public func hasExtension(ext: UXCUbiregiExtension) -> Bool {
        return self.lock.read { self._extensions.contains(ext) }
    }
    
    public func findExtensionForHostname(hostname: String, port: UInt) -> UXCUbiregiExtension? {
        return self.lock.read {
            for ext in self._extensions {
                if ext.hostname == hostname && ext.port == port {
                    return ext
                }
            }
            
            return nil
        }
    }
    
    public func eachExtension(proc: (UXCUbiregiExtension) -> ()) {
        self.lock.read {
            self._extensions.forEach(proc)
        }
    }
    
    public func anyExtension(test: (UXCUbiregiExtension) -> Bool) -> Bool {
        return self.lock.read {
            for ext in self._extensions {
                if test(ext) {
                    return true
                }
            }
            
            return false
        }
    }
    
    public func allExtension(test: (UXCUbiregiExtension) -> Bool) -> Bool {
        return self.lock.read {
            for ext in self._extensions {
                if !test(ext) {
                    return false
                }
            }
            
            return true
        }
    }
    
    public func updateStatus(callback: () -> () = {}) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let semaphore = dispatch_semaphore_create(0)
            
            let extensions = self.extensions
            
            for ext in extensions {
                ext.updateStatus {
                    dispatch_semaphore_signal(semaphore)
                }
            }
            
            for _ in extensions {
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            }
            
            callback()
        }
    }
    
    private func postNotification(name: String, userInfo: [NSObject: AnyObject]? = nil) {
        dispatch_async(self.notificationQueue) {
            NSNotificationCenter.defaultCenter().postNotificationName(name, object: self, userInfo: userInfo)
        }
    }
    
    func updateConnectionStatus() {
        self.lock.write {
            let newStatus = self._extensions.reduce(UXCConnectionStatus.Initialized) { (status, ext) in
                switch status {
                case .Initialized:
                    return ext.connectionStatus
                case .Connected:
                    return .Connected
                case .Error:
                    if ext.connectionStatus == .Connected {
                        return .Connected
                    } else {
                        return .Error
                    }
                }
            }
            
            if newStatus != self._connectionStatus {
                let oldStatus = self._connectionStatus
                
                self._connectionStatus = newStatus
                self.postNotification(
                    UXCConstants.UbiregiExtensionServiceDidUpdateConnectionStatusNotification,
                    userInfo: [
                        "oldConnectionStatus": oldStatus.rawValue,
                        "newConnectionStatus": newStatus.rawValue
                    ]
                )
            }
        }
    }
    
    func updateDeviceAvailability() {
        let hasPrinter = self.anyExtension { $0.hasPrinter && $0.connectionStatus == .Connected }
        let hasBarcodeScanner = self.anyExtension { $0.hasBarcodeScanner && $0.connectionStatus == .Connected }
        
        self.lock.write {
            if hasPrinter != self._isPrinterAvailable {
                self._isPrinterAvailable = hasPrinter
                self.postNotification(UXCConstants.UbiregiExtensionServiceDidUpdatePrinterAvailabilityNotification)
            }
            
            if hasBarcodeScanner != self._isBarcodeScannerAvailable {
                self._isBarcodeScannerAvailable = hasBarcodeScanner
                self.postNotification(UXCConstants.UbiregiExtensionServiceDidUpdateBarcodeScannerAvailabilityNotification)
            }
        }
    }
    
    func connectionStatusDidUpdate(notification: NSNotification) {
        if self.hasExtension(notification.object as! UXCUbiregiExtension) {
            self.updateConnectionStatus()
            self.updateDeviceAvailability()
        }
    }
    
    func statusDidUpdate(notification: NSNotification) {
        if self.hasExtension(notification.object as! UXCUbiregiExtension) {
            self.updateDeviceAvailability()
        }
    }
    
    func didScanBarcode(notification: NSNotification) {
        let barcodeScanner = notification.object as! UXCBarcodeScanner
        if self._barcodeScanners[barcodeScanner.ext] != nil {
            self.postNotification(UXCConstants.UbiregiExtensionServiceDidScanBarcodeNotification, userInfo: notification.userInfo)
        }
    }
}