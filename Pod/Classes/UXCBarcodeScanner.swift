import Foundation

let BarcodeScannerDidScanBarcodeNotification = "UXCBarcodeScannerDidScanBarcodeNotification"
let BarcodeScannerScanedBarcodeKey = "barcode"

class UXCBarcodeScanner: NSObject {
    let lock: ReadWriteLock
    let ext: UXCUbiregiExtension
    var isScanning: Bool
    var isIdle: Bool
    
    init(ext: UXCUbiregiExtension) {
        self.lock = ReadWriteLock()
        self.ext = ext
        self.isScanning = false
        self.isIdle = false
        
        super.init()
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "onBarcodeScannerAvailabilityUpdate:", name: UbiregiExtensionDidUpdateBarcodeScannerAvailabilityNotification, object: self.ext)
        notificationCenter.addObserver(self, selector: "onBarcodeScannerAvailabilityUpdate:", name: UbiregiExtensionDidUpdateConnectionStatusNotification, object: self.ext)
        
        self.tryScan()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func tryScan() {
        self.lock.write {
            guard !self.isIdle else {
                return
            }
            guard !self.isScanning else {
                return
            }
            
            self.isScanning = true

            weak var weakSelf: UXCBarcodeScanner? = self
            
            self.ext.scanBarcode { barcode in
                guard let this = weakSelf else {
                    return
                }
                
                this.lock.write {
                    if this.isScanning {
                        if let barcode = barcode {
                            NSNotificationCenter.defaultCenter().postNotificationName(BarcodeScannerDidScanBarcodeNotification, object: this, userInfo: [BarcodeScannerScanedBarcodeKey: barcode])
                        }
                        this.isScanning = false
                    }
                    
                    if !this.isIdle {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                            this.tryScan()
                        }
                    }
                }
            }
        }
    }
    
    func onBarcodeScannerAvailabilityUpdate(notification: NSNotification) {
        self.lock.write {
            if self.ext.connectionStatus == .Connected && self.ext.hasBarcodeScanner {
                self.isIdle = false
                
                if !self.isScanning {
                    self.tryScan()
                }
            } else {
                self.isIdle = true
            }
        }
    }
}