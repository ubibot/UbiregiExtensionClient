import Foundation

class ReadWriteLock {
    let queue: dispatch_queue_t
    
    init() {
        self.queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    }
    
    func write<T>(k: () -> T) -> T {
        var ret: T! = nil
        dispatch_barrier_sync(self.queue) {
            ret = k()
        }
        return ret
    }
    
    func writeAsync(k: () -> ()) {
        dispatch_barrier_async(self.queue, k)
    }
    
    func read<T>(k: () -> T) -> T {
        var ret: T! = nil
        dispatch_sync(self.queue) {
            ret = k()
        }
        return ret
    }
    
    func readAsync(k: () -> ()) {
        dispatch_async(self.queue, k)
    }
}