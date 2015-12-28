import Foundation

@objc public enum UXCAPIResponseError: Int, ErrorType {
    case UnexpectedResponse
}

@objc public class UXCAPIResponse: NSObject {
    public func trySuccessResponse(block: (UXCAPISuccessResponse) -> ()) -> () {
        // Nothing to do
    }
    
    public func tryErrorResponse(block: (UXCAPIErrorResponse) -> ()) -> () {
        // Nothing to do
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
        guard let contentType = self.contentType else {
            return nil
        }
        
        guard contentType.hasPrefix("application/json") else {
            return nil
        }
        
        do {
            return try NSJSONSerialization.JSONObjectWithData(self.body, options: NSJSONReadingOptions.MutableContainers)
        } catch _ {
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
    
    override public func trySuccessResponse(block: (UXCAPISuccessResponse) -> ()) {
        block(self)
    }
}

@objc public class UXCAPIErrorResponse: UXCAPIResponse {
    public let error: NSError
    
    internal init(error: NSError) {
        self.error = error
    }
    
    override public func tryErrorResponse(block: (UXCAPIErrorResponse) -> ()) {
        block(self)
    }
}

