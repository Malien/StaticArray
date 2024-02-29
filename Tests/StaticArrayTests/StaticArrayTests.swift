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
            struct IPv4: UnsafeStaticArrayProtocol, ExpressibleByArrayLiteral, CustomStringConvertible {
                var repr: (UInt8, UInt8, UInt8, UInt8)
            
                typealias Element = UInt8
            
                init(_ repr: (UInt8, UInt8, UInt8, UInt8)) {
                    self.repr = repr
                }
            
                init(_ v0: UInt8, _ v1: UInt8, _ v2: UInt8, _ v3: UInt8) {
                    self.repr = (v0, v1, v2, v3)
                }
            
                enum Index: Int, CaseIterable {
                    case i0, i1, i2, i3
                }
            
                var description: String {
                    "[\\(repr.0), \\(repr.1), \\(repr.2), \\(repr.3)]"
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
            """,
            diagnostics: [
                DiagnosticSpec(message: "Count of #StaticArray should be at least 2. Got 1", line: 1, column: 25)
            ],
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
                DiagnosticSpec(message: "Count of #StaticArray should be at least 2. Got 0", line: 1, column: 26)
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
                DiagnosticSpec(message: "Count of #StaticArray should be at least 2. Got -1", line: 1, column: 26)
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
