@freestanding(declaration, names: arbitrary)
public macro StaticArray<Element>(count: Count, named: StaticString, visibility: Visibility = .none) = #externalMacro(module: "StaticArrayMacros", type: "StaticArrayMacro")

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
