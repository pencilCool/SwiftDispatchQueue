//
//  SwiftThreadPool.swift
//  SwiftDispatchQueue
//
//  Created by yuhua Tang on 2022/7/22.
//

import Foundation

class SwiftThreadPool {
    
    /*
     线程池将被多个线程访问，包括内部和外部的，因此需要线程安全。虽然GCD尽可能地使用快速原子操作，但对于我的概念性重建，我还是要坚持使用老式的锁。我需要在这个锁上等待和发出信号的能力，而不仅仅是执行互斥，所以我使用了一个NSCondition而不是一个普通的NSLock。如果你对它不熟悉，NSCondition基本上是一个锁和一个单一的条件变量包装在一起的。
     */
    var lock:NSCondition = NSCondition()
    
    
    /*
     为了知道何时启动新的工作线程，我需要知道池子里有多少线程，有多少线程实际在忙着工作，以及我可以拥有的最大线程数。
     */
    
    var threadCount:Int = 0
    var activeThreadCount:Int = 0
    var threadCountLimit:Int = 128
    
    /*
     最后，有一个要执行的块的列表。这是一个array，它被当作一个队列，将新的区块追加到末尾，并从前面删除。
     */
    
    var closures = [()->Void]()
    
    func add(_ closure:@escaping () -> Void) {
        lock.lock()
        closures.append(closure)
        /*
         如果有一个空闲的工作线程准备好接受这个区块，那么就没有什么可做的了。如果没有足够的空闲工作线程来处理所有未完成的区块，而且工作线程的数量还没有达到极限，那么就应该创建一个新的工作线程。

         */
        let idleThreads = threadCount - activeThreadCount
        
        if closures.count > idleThreads,threadCount < threadCountLimit {
            Thread.detachNewThreadSelector(#selector(SwiftThreadPool.workerThreadLoop(_:)), toTarget: self, with: nil)
        }
        
        lock.signal()
        lock.unlock()
        
    }
    
    
    /*
     工作线程运行一个简单的无限循环。只要区块阵列是空的，它就会等待。一旦有一个区块可用，它将从数组中提取并执行它。在这样做的时候，它将增加活动线程的数量，然后在完成后再减去它。让我们开始吧。
     */
    @objc func workerThreadLoop(_ ignore:Bool) {
        /*
         它做的第一件事是获取锁。注意，它是在循环开始之前做的。原因将在循环结束时变得清晰。
         */
        lock.lock()
        while true {
            // If the queue is empty, wait on the lock:
            while(closures.isEmpty) {
                // 请注意，这是用一个循环来完成的，而不只是一个if语句。这样做的原因是虚假的唤醒。简而言之，即使没有信号，wait也有可能返回，所以为了正确的行为，当wait返回时需要重新评估被检查的条件。
                lock.wait()
            }
            
            let closure = Array(closures.dropFirst())[0]
            activeThreadCount += 1
            lock.unlock()
            closure()
            lock.lock()
            activeThreadCount -= 1
        }
        
    }
}
