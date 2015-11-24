import Foundation

@objc public enum UXCErrorCode: Int {
    case Unknown
    case NameResolution
    case ConnectionFailure
    case Timeout
}

public class UXCConstants: NSObject {
    public static let ErrorDomain = "UbiregiExtensionClientErrorDomain"
    
    public static let UbiregiExtensionServiceDidUpdateConnectionStatusNotification = "UXCUbiregiExtensionServiceDidUpdateConnectionStatusNotification"
    public static let UbiregiExtensionServiceDidUpdatePrinterAvailabilityNotification = "UXCUbiregiExtensionServiceDidUpdatePrinterAvailabilityNotification"
    public static let UbiregiExtensionServiceDidUpdateBarcodeScannerAvailabilityNotification = "UXCUBiregiExtensionServiceDidUpdateBarcodeScannerAvailabilityNotification"
    public static let UbiregiExtensionServiceDidScanBarcodeNotification = "UXCUbiregiExtensionServiceDidScanBarcodeNotification";
    public static let UbiregiExtensionServiceScanedBarcodeKey = BarcodeScannerScanedBarcodeKey
}

@objc public enum UXCConnectionStatus: Int {
    case Initialized
    case Connected
    case Error
}