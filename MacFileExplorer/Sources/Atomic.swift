import Foundation

/// Lightweight atomic property wrapper backed by NSLock for simple thread-safe mutations.
@propertyWrapper
final class Atomic<Value> {
    private let lock = NSLock()
    private var value: Value

    init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    var wrappedValue: Value {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }

    var projectedValue: Atomic<Value> { self }

    /// Allows in-place mutation while holding the lock.
    @discardableResult
    func update<T>(_ mutation: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return mutation(&value)
    }
}

private extension NSLock {
    func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}
