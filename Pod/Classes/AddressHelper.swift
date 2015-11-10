import Foundation

func in_addr_from_sockaddr<T>(address: sockaddr, closure: (UnsafePointer<Void>) -> T) -> T {
    var a = address
    var result: T? = nil
    
    if Int32(a.sa_family) == PF_INET {
        withUnsafePointer(&a) { sockaddr_ptr in
            let sockaddr_in_ptr = unsafeBitCast(sockaddr_ptr, UnsafePointer<sockaddr_in>.self)
            var in_addr = sockaddr_in_ptr.memory.sin_addr
            withUnsafePointer(&in_addr) {
                result = closure(unsafeBitCast($0, UnsafePointer<Void>.self))
            }
        }
    }
    
    if Int32(a.sa_family) == PF_INET6 {
        withUnsafePointer(&a) { sockaddr_ptr in
            let sockaddr_in6_ptr = unsafeBitCast(sockaddr_ptr, UnsafePointer<sockaddr_in6>.self)
            var in_addr = sockaddr_in6_ptr.memory.sin6_addr
            withUnsafePointer(&in_addr) {
                result = closure(unsafeBitCast($0, UnsafePointer<Void>.self))
            }
        }
    }
    
    return result!
}

func numericAddress(address: sockaddr) -> String {
    return in_addr_from_sockaddr(address) { (in_addr: UnsafePointer<Void>) -> String in
        let buf = UnsafeMutablePointer<Int8>.alloc(256)
        inet_ntop(Int32(address.sa_family), in_addr, buf, 256)
        return String.fromCString(unsafeBitCast(buf, UnsafeMutablePointer<CChar>.self))!
    }
}

