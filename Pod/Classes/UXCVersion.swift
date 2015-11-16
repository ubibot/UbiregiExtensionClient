import Foundation

public class UXCVersion: NSObject {
    let major: Int
    let minor: Int
    let patch: Int
    let label: String?
    let string: String
    
    init(string: String) {
        self.string = string
        
        let labels: [String] = string.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "-"))
        let numbers = labels[0].componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "."))
        
        self.major = numbers.count > 0 ? Int(numbers[0])! : 0
        self.minor = numbers.count > 1 ? Int(numbers[1])! : 0
        self.patch = numbers.count > 2 ? Int(numbers[2])! : 0
        
        if labels.count >= 2 {
            self.label = Array(labels[1..<labels.count]).joinWithSeparator("-")
        } else {
            self.label = nil
        }
    }
    
    override public func isEqual(object: AnyObject?) -> Bool {
        if let v = object as? UXCVersion {
            return self == v
        } else {
            return false
        }
    }
    
    override public var description: String {
        return "UXCVersion(\(self.string))"
    }
}

func ==(v1: UXCVersion, v2: UXCVersion) -> Bool {
    return v1.major == v2.major && v1.minor == v2.minor && v1.patch == v2.patch && v1.label == v2.label
}