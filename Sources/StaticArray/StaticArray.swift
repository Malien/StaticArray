@freestanding(declaration, names: arbitrary)
public macro StaticArray<Element>(count: Count, named: StaticString, visibility: Visibility = .none) = #externalMacro(module: "StaticArrayMacros", type: "StaticArrayMacro")

/// It is unsafe to implement `UnsafeStaticArrayProtocol` outside of the #StaticArray macro
/// `Repr` type and `repr` field has to have special properties, like:
/// - Invariant:
///     - `Repr` is a homogeneous tuple type
///     - `repr` is a field, not a getter/setter pair
///     -  `count` is an accurate amount of values in a `repr` tuple
public protocol UnsafeStaticArrayProtocol {
    associatedtype Element
    associatedtype Repr: Sendable
    associatedtype Index: CaseIterable, RawRepresentable<Int>
    var repr: Repr { get set }
}

public extension UnsafeStaticArrayProtocol {
    /// Gives an iterator to the underlying memory, which is only valid during the duration of `withUnsafeBuffer` call.
    /// - Invariant:
    ///     Iterator passed into the closure cannot escape it. Any use of the iterator outside of it is unsafe and will result in undefined behaviour
    func withUnsafeBuffer<T>(_ body: (UnsafeBufferPointer<Element>) throws -> T) rethrows -> T {
        return try withUnsafeBytes(of: self.repr) { ptr in
            return try body(ptr.assumingMemoryBound(to: Element.self))
        }
    }
    
    mutating func withUnsafeMutableBuffer<T>(_ body: (UnsafeMutableBufferPointer<Element>) throws -> T) rethrows -> T {
        return try withUnsafeMutableBytes(of: &self.repr) { ptr in
            return try body(ptr.assumingMemoryBound(to: Element.self))
        }
    }
    
    static var count: Int {
        MemoryLayout<Repr>.size / MemoryLayout<Element>.stride
    }
    
    subscript(_ index: Index) -> Element {
        get {
            self.withUnsafeBuffer { $0[index.rawValue] }
        }
        set {
            self.withUnsafeMutableBuffer { $0[index.rawValue] = newValue }
        }
    }
    
    subscript(safe intIndex: Int) -> Element? {
        guard let index = Index(rawValue: intIndex) else { return nil }
        return self[index]
    }

    subscript(_ intIndex: Int) -> Element {
        get {
            guard let index = Index(rawValue: intIndex)
            else {
                preconditionFailure(
                    "Attempted to access a static array \(Self.self) (size: \(Self.count)) with an integer index out of bounds (index: \(intIndex))"
                )
            }
            return self[index]
        }
        set {
            guard let index = Index(rawValue: intIndex)
            else {
                preconditionFailure(
                    "Attempted to write to a static array \(Self.self) (size: \(Self.count)) with an integer index out of bounds (index: \(intIndex))"
                )
            }
            self[index] = newValue
        }
    }
    
    
    func forEach(_ body: (Element) throws -> ()) rethrows {
        try withUnsafeBuffer { try $0.forEach(body) }
    }
    
    func reduce(_ initialResult: Element, _ nextPartialResult: (Element, Element) throws -> Element) rethrows -> Element {
        try withUnsafeBuffer { try $0.reduce(initialResult, nextPartialResult) }
    }
    
    func contains(_ element: Element) -> Bool where Element: Equatable {
        withUnsafeBuffer { $0.contains(element) }
    }
    
    func contains(where condition: (Element) throws -> Bool) rethrows -> Bool {
        try withUnsafeBuffer { try $0.contains(where: condition) }
    }
    
    func allSatisfy(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        try withUnsafeBuffer { try $0.allSatisfy(predicate) }
    }
    
    func elementsEqual(_ other: some Sequence<Element>) -> Bool where Element: Equatable {
        withUnsafeBuffer { $0.elementsEqual(other) }
    }
    
    func elementsEqual<T: Sequence>(_ other: T, by predicate: (Element, T.Element) throws -> Bool ) rethrows -> Bool {
        try withUnsafeBuffer { try $0.elementsEqual(other, by: predicate) }
    }
    
    func lexicographicallyPrecedes(_ other: some Sequence<Element>) -> Bool where Element: Comparable {
        withUnsafeBuffer { $0.lexicographicallyPrecedes(other) }
    }
    
    func lexicographicallyPrecedes(_ other: some Sequence<Element>, by predicate: (Element, Element) throws -> Bool) rethrows -> Bool {
        try withUnsafeBuffer { try $0.lexicographicallyPrecedes(other, by: predicate) }
    }
    
    func starts(with other: some Sequence<Element>) -> Bool where Element: Equatable {
        withUnsafeBuffer { $0.starts(with: other) }
    }
    
    func starts<T: Sequence>(with other: T, by predicate: (Element, T.Element) throws -> Bool) rethrows -> Bool {
        try withUnsafeBuffer { try $0.starts(with: other, by: predicate) }
    }
    
    func min(by predicate: (Element, Element) throws -> Bool) rethrows -> Element {
        try withUnsafeBuffer { try $0.min(by: predicate)! }
    }
    
    func max(by predicate: (Element, Element) throws -> Bool) rethrows -> Element {
        try withUnsafeBuffer { try $0.max(by: predicate)! }
    }
    
    // Only if underlying type is comparable
    func min() -> Element where Element: Comparable {
        withUnsafeBuffer { $0.min()! }
    }
    
    func max() -> Element where Element: Comparable {
        withUnsafeBuffer { $0.max()! }
    }
}

public enum Visibility {
    case `public`, `private`, `none`, `fileprivate`
}

extension Visibility: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .none }
}

public struct Count { }
extension Count: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Int
    public init(integerLiteral value: Int) { }
}
