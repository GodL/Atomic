//
//  Atomic.swift
//  Atomic
//
//  Created by lihao10 on 2020/9/11.
//

import Foundation

open class SpinLock {
    
    @available(iOS 10.0,*)
    private class UnfairLock: SpinLock {
        private let _lock: os_unfair_lock_t
        override init() {
            _lock = .allocate(capacity: 1)
            _lock.initialize(to: os_unfair_lock())
            super.init()
        }
        
        override func lock() {
            os_unfair_lock_lock(_lock)
        }
        
        override func unLock() {
            os_unfair_lock_unlock(_lock)
        }
        
        override func tryLock() -> Bool {
            return os_unfair_lock_trylock(_lock)
        }
        
        deinit {
            _lock.deinitialize(count: 1)
            _lock.deallocate()
        }
    }
    
    
    public class PthreadLock: SpinLock {
        private let _lock: UnsafeMutablePointer<pthread_mutex_t>
        
        init(recursive: Bool = false) {
            _lock = .allocate(capacity: 1)
            _lock.initialize(to: pthread_mutex_t())
            
            let attr = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: 1)
            attr.initialize(to: pthread_mutexattr_t())
            pthread_mutexattr_init(attr)
            
            defer {
                pthread_mutexattr_destroy(attr)
                attr.deinitialize(count: 1)
                attr.deallocate()
            }
            
            pthread_mutexattr_settype(attr,recursive ? PTHREAD_MUTEX_RECURSIVE : PTHREAD_MUTEX_ERRORCHECK)
            
            pthread_mutex_init(_lock, attr)
            
            super.init()
        }
        
        public override func lock() {
            pthread_mutex_lock(_lock)
        }
        
        public override func unLock() {
            pthread_mutex_unlock(_lock)
        }
        
        public override func tryLock() -> Bool {
            return (pthread_mutex_trylock(_lock) != 0)
        }
        
        deinit {
            pthread_mutex_destroy(_lock)
            _lock.deinitialize(count: 1)
            _lock.deallocate()
        }
    }
    
    public static func make() -> SpinLock {
        if #available(iOS 10.0, *) {
            return UnfairLock()
        }else {
            return PthreadLock()
        }
    }
    
    private init() {}
    
    open func lock() { fatalError() }
    
    open func unLock() { fatalError() }
    
    open func tryLock() -> Bool { fatalError() }
}


public final class Atomic<Value> {
    private let lock: SpinLock
    
    private var _value: Value?
    
    public var value: Value? {
        get {
            with { _value }
        }
        
        set {
            swap(newValue)
        }
    }
    
    public convenience init(_ value: Value) {
        self.init()
        self._value = value
    }
    
    public init() {
        lock = SpinLock.make()
    }
    
    public func `do`(_ action:() -> Void) {
        lock.lock(); defer { lock.unLock() }
        action()
    }
    
    public func with<Result>(_ action:() -> Result) -> Result {
        lock.lock(); defer { lock.unLock() }
        return action()
    }
    
    public func map<Result>(_ action:(Value) -> Result) -> Result {
        lock.lock(); defer { lock.unLock() }
        return action(_value!)
    }
    
    @discardableResult
    public func swap(_ newValue: Value?) ->Value? {
        return with { () -> Value? in
            let old = _value
            self._value = newValue
            return old
        }
    }
}

public struct UnsafeAtomic<Value> {
    private let point: UnsafeMutablePointer<Value> = UnsafeMutablePointer<Value>.allocate(capacity: 1)
    
    public var value: Value {
        point.pointee
    }
        
    public func deinititalize() {
        point.deinitialize(count: 1)
        point.deallocate()
    }
}

extension UnsafeAtomic where Value == Int32 {
    
    public init(_ value: Value) {
        point.initialize(to: value)
    }
    
    @discardableResult
    public func increment() -> Value {
        return OSAtomicIncrement32Barrier(point)
    }
    
    @discardableResult
    public func decrement() -> Value {
        return OSAtomicDecrement32Barrier(point)
    }
    
    @discardableResult
    public func cas(old: Value,new: Value) -> Bool {
        return OSAtomicCompareAndSwap32Barrier(old, new, point)
    }
}

extension UnsafeAtomic where Value == Int64 {
    public init(_ value: Value) {
        point.initialize(to: value)
    }
    
    @discardableResult
    public func increment() -> Value {
        return OSAtomicIncrement64Barrier(point)
    }
    
    @discardableResult
    public func decrement() -> Value {
        return OSAtomicDecrement64Barrier(point)
    }
    
    @discardableResult
    public func cas(old: Value,new: Value) -> Bool {
        return OSAtomicCompareAndSwap64Barrier(old, new, point)
    }
}

public struct UnsafeAtomicBool {
    private var atomic: UnsafeAtomic<Int32>
    
    public var bool: Bool {
        atomic.value == 1
    }
    
    public init(_ bool: Bool = false) {
        atomic = UnsafeAtomic(bool ? 1 : 0)
    }
    
    public func deinititalize() {
        atomic.deinititalize()
    }
    
    public func `true`() -> Bool  {
        return atomic.cas(old: 0, new: 1)
    }
    
    public func `false`() -> Bool {
        return atomic.cas(old: 1, new: 0)
    }
    
    public func toggle() -> Bool {
        if bool {
            return atomic.cas(old: 1, new: 0)
        }else {
            return atomic.cas(old: 0, new: 1)
        }
    }
}
