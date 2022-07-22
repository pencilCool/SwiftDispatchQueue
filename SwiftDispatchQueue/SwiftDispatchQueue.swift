//
//  SwiftDispatchQueue.swift
//  SwiftDispatchQueue
//
//  Created by yuhua Tang on 2022/7/22.
//

import Foundation

class SwiftDispatchQueue {
    static let globalQueue = SwiftDispatchQueue()
    static let gThreadPool = SwiftThreadPool()
    /*
     像线程池一样，队列将使用一个锁来保护它的内容。与线程池不同，它不需要做任何等待或信号，只是基本的互斥，所以它使用一个普通的NSLock。
     */
    
    var lock = NSLock()
    var  pendingClosures = [()->Void]()
   
    // 队列知道它是串行的还是并发的。
    var serial = false
    
    // 串行时，它还会跟踪当前是否有一个块在线程池中运行。
    // 无论是否有东西在运行，并发队列的行为都是一样的，所以它们不跟踪这个
    
    var serialRunning:Bool = false
    
    init() {
        
    }
    
    init(serial:Bool) {
        self.serial = serial
    }
    
    func dispatchAsync(_ closure:@escaping () -> Void) {
        lock.lock()
        pendingClosures.append(closure)
        
        if serial && !serialRunning {
            serialRunning = true
            dispatch()
        } else if (!serial) {
            dispatch()
        }
        lock.unlock()
    }
    
    func dispatchSync(_ closure:@escaping () -> Void) {
       let condition = NSCondition()
        var done = false
        dispatchAsync {
            closure()
            condition.lock()
            done = true
            condition.signal()
            condition.unlock()
        }
        
        condition.lock()
        while !done {
            condition.wait()
        }
        condition.unlock()
    }
    
    
    
    private func dispatch() {
        SwiftDispatchQueue.gThreadPool.add {
            [weak self] in
            guard let self = self else {
                return
            }
            self.lock.lock()
            let closure = Array(self.pendingClosures.dropFirst())[0]
            self.lock.unlock()
            closure()
            if self.serial {
                self.lock.lock()
                if !self.pendingClosures.isEmpty {
                    self.dispatch()
                } else {
                    self.serialRunning = false
                }
                self.lock.unlock()
            }
        }
    }
}


