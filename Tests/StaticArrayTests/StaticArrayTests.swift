import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

import SwiftSyntax
import SwiftSyntaxBuilder

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(StaticArrayMacros)
import StaticArrayMacros

let testMacros: [String: Macro.Type] = [
    "StaticArray": StaticArrayMacro.self,
]
#endif

final class StaticArrayTests: XCTestCase {
    func testIPv4() throws {
        #if canImport(StaticArrayMacros)
        assertMacroExpansion(
            """
            #StaticArray<UInt8>(count: 4, named: "IPv4")
            """,
            expandedSource: """
            struct IPv4: ExpressibleByArrayLiteral {
                var repr: (UInt8, UInt8, UInt8, UInt8)
            
                init(_ repr: (UInt8, UInt8, UInt8, UInt8)) {
                    self.repr = repr
                }
            
                init(_ v0: UInt8, _ v1: UInt8, _ v2: UInt8, _ v3: UInt8) {
                    self.repr = (v0, v1, v2, v3)
                }
            
                enum Index: CaseIterable, Int {
                    case i0, i1, i2, i3
                }
            
                subscript(_ index: Index) -> UInt8 {
                    get {
                        switch index {
                        case .i0:
                            return repr.0
                        case .i1:
                            return repr.1
                        case .i2:
                            return repr.2
                        case .i3:
                            return repr.3
                        }
                    }
                    set {
                        switch index {
                        case .i0:
                            repr.0 = newValue
                        case .i1:
                            repr.1 = newValue
                        case .i2:
                            repr.2 = newValue
                        case .i3:
                            repr.3 = newValue
                        }
                    }
                }
            
                subscript(safe intIndex: Int) -> UInt8? {
                    guard let index = Index(rawValue: intIndex) else {
                        return nil
                    }
                    return self [index]
                }
            
                subscript(_ intIndex: Int) -> UInt8 {
                    get {
                        guard let index = Index(rawValue: intIndex)
                        else {
                            preconditionFailure(
                                            "Attempted to access a static array IPv4 (size: 4) with an integer index out of bounds (index: \\(intIndex))"
                                        )
                        }
                        return self [index]
                    }
                    set {
                        guard let index = Index(rawValue: intIndex)
                        else {
                            preconditionFailure(
                                            "Attempted to write to a static array IPv4 (size: 4) with an integer index out of bounds (index: \\(intIndex))"
                                        )
                        }
                        self [index] = newValue
                    }
                }
            
                typealias ArrayLiteralElement = UInt8
                init(arrayLiteral elements: UInt8...) {
                    precondition(elements.count == 4, "Type IPv4 (#StaticArray) can only be initialized with array literals with exact size of 4. Got a literal with \\(elements.count) elements")
                    self.repr = (elements[0], elements[1], elements[2], elements[3])
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testWrapper() throws {
        #if canImport(StaticArrayMacros)
        assertMacroExpansion(
            """
            #StaticArray<()>(count: 1, named: "VoidWrapper")
            """,
            expandedSource: """
            struct VoidWrapper: ExpressibleByArrayLiteral {
                var repr: (())
            
                init(_ repr: (())) {
                    self.repr = repr
                }
            
                init(_ v0: ()) {
                    self.repr = (v0)
                }
            
                enum Index: CaseIterable, Int {
                    case i0
                }
            
                subscript(_ index: Index) -> () {
                    get {
                        switch index {
                        case .i0:
                            return repr.0
                        }
                    }
                    set {
                        switch index {
                        case .i0:
                            repr.0 = newValue
                        }
                    }
                }
            
                subscript(safe intIndex: Int) -> ()? {
                    guard let index = Index(rawValue: intIndex) else {
                        return nil
                    }
                    return self [index]
                }
            
                subscript(_ intIndex: Int) -> () {
                    get {
                        guard let index = Index(rawValue: intIndex)
                        else {
                            preconditionFailure(
                                            "Attempted to access a static array VoidWrapper (size: 1) with an integer index out of bounds (index: \\(intIndex))"
                                        )
                        }
                        return self [index]
                    }
                    set {
                        guard let index = Index(rawValue: intIndex)
                        else {
                            preconditionFailure(
                                            "Attempted to write to a static array VoidWrapper (size: 1) with an integer index out of bounds (index: \\(intIndex))"
                                        )
                        }
                        self [index] = newValue
                    }
                }
            
                typealias ArrayLiteralElement = ()
                init(arrayLiteral elements: ()...) {
                    precondition(elements.count == 1, "Type VoidWrapper (#StaticArray) can only be initialized with array literals with exact size of 1. Got a literal with \\(elements.count) elements")
                    self.repr = (elements[0])
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testZST() throws {
        #if canImport(StaticArrayMacros)
        assertMacroExpansion(
            """
            #StaticArray<Int>(count: 0, named: "ZST")
            """,
            expandedSource: """
            """,
            diagnostics: [
                DiagnosticSpec(message: "Count of #StaticArray should be a positive (non-zero) integer. Got 0", line: 1, column: 26)
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testNegativeCount() throws {
        #if canImport(StaticArrayMacros)
        assertMacroExpansion(
            """
            #StaticArray<Int>(count: -1, named: "NegativeMass")
            """,
            expandedSource: """
            """,
            diagnostics: [
                DiagnosticSpec(message: "Count of #StaticArray should be a positive (non-zero) integer. Got -1", line: 1, column: 26)
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
