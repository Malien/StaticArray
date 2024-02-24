import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

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
            
                enum Index: CaseIterable, Int {
                    case i0, i1, i2, i3
                }
            
                subscript(_ index: Index) -> UInt8 {
                    switch (index, repr) {
                        case (.i0, (let x, _, _, _)), (.i1, (_, let x, _, _)), (.i2, (_, _, let x, _)), (.i3, (_, _, _, let x)):
                        return x
                    }
                }
            
                subscript(safe intIndex: Int) -> UInt8? {
                    guard let index = Index(rawValue: index) else {
                        return nil
                    }
                    return self [index]
                }
            
                subscript(_ intIndex: Int) -> UInt8 {
                    guard let value = self [safe: intIndex]
                    else {
                        preconditionFailure(
                                    "Attempted to access a static array IPv4 (size: 4) with an integer index out of bounds (index: \\(intIndex))"
                                )
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
            
                enum Index: CaseIterable, Int {
                    case i0
                }
            
                subscript(_ index: Index) -> () {
                    switch (index, repr) {
                        case (.i0, (let x)):
                        return x
                    }
                }
            
                subscript(safe intIndex: Int) -> ()? {
                    guard let index = Index(rawValue: index) else {
                        return nil
                    }
                    return self [index]
                }
            
                subscript(_ intIndex: Int) -> () {
                    guard let value = self [safe: intIndex]
                    else {
                        preconditionFailure(
                                    "Attempted to access a static array VoidWrapper (size: 1) with an integer index out of bounds (index: \\(intIndex))"
                                )
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
