import Foundation

@objc public enum UXCAPIResponseError: Int, ErrorType {
    case UnexpectedResponse
}

@objc public class UXCAPIResponse: NSObject {
    public func trySuccessResponse(block: (UXCAPISuccessResponse) -> ()) throws -> () {
        throw UXCAPIResponseError.UnexpectedResponse
    }
    
    public func tryErrorResponse(block: (UXCAPIErrorResponse) -> ()) throws -> () {
        throw UXCAPIResponseError.UnexpectedResponse
    }
}

@objc public class UXCAPISuccessResponse: UXCAPIResponse {
    public let code: Int
    public let header: [String: String]
    public let body: NSData
    
    internal init(code: Int, header: [String: String], body: NSData) {
        self.code = code
        self.header = header
        self.body = body
    }
    
    public var JSONBody: AnyObject? {
        if self.contentType == "application/json" {
            do {
                return try NSJSONSerialization.JSONObjectWithData(self.body, options: NSJSONReadingOptions.MutableContainers)
            } catch _ {
                return nil
            }
        } else {
            return nil
        }
    }
    
    public var contentType: String? {
        for (key, value) in self.header {
            if key.uppercaseString == "Content-Type".uppercaseString {
                return value
            }
        }
        
        return nil
    }
    
    override public func trySuccessResponse(block: (UXCAPISuccessResponse) -> ()) throws {
        block(self)
    }
}

@objc public class UXCAPIErrorResponse: UXCAPIResponse {
    public let error: NSError
    
    internal init(error: NSError) {
        self.error = error
    }
    
    override public func tryErrorResponse(block: (UXCAPIErrorResponse) -> ()) throws {
        block(self)
    }
}

