import Foundation

public enum UXCErrorCode: Int {
    case Unknown
    case NameResolution
    case ConnectionFailure
    case Timeout
}

public class UXCConstants: NSObject {
    public static let ErrorDomain = "UbiregiExtensionClientErrorDomain"
}

@objc public enum UXCConnectionStatus: Int {
    case Initialized
    case Connected
    case Error
}