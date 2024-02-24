import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum StaticArrayExpansionError: CustomStringConvertible, Error {
    case invalidName, invalidCount(got: ExprSyntax?), noGenericType
    
    public var description: String {
        switch self {
        case .invalidName:
            return "#StaticArray expected to receive an argument `named:` which should be a string literal"
        case .invalidCount(got: nil):
            return "#StaticArray expected to receive an argument `count:` which should be a positive number literal"
        case .invalidCount(got: let got?):
            return "Count of #StaticArray should be a positive (non-zero) integer. Got \(got)"
        case .noGenericType:
            return "#StaticArray requires setting an element type explicitly using swift's generics syntax, aka: #StaticArray<ElementType>(count: 5, named: \"MyArray\")"
        }
    }
}

public struct StaticArrayMacro: DeclarationMacro {
    public static func expansion(
        of node: some SwiftSyntax.FreestandingMacroExpansionSyntax,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let nameStr = node.argumentList
            .first(where: { $0.label?.text == "named" })?
            .expression
            .as(StringLiteralExprSyntax.self)?
            .representedLiteralValue
        else { throw StaticArrayExpansionError.invalidName }
        let name = TokenSyntax.identifier(nameStr)
        
        guard let countArg = node.argumentList
            .first(where: { $0.label?.text == "count" })?
            .expression
        else { throw StaticArrayExpansionError.invalidCount(got: nil) }
        guard let count = countArg
            .as(IntegerLiteralExprSyntax.self)?
            .literal
            .text
            .toInt()
        else {
            context.addDiagnostics(from: StaticArrayExpansionError.invalidCount(got: countArg), node: countArg)
            return []
        }
        if count <= 0 {
            context.addDiagnostics(from: StaticArrayExpansionError.invalidCount(got: countArg), node: countArg)
            return []
        }
        
        guard let elementType = node.genericArgumentClause?.arguments.first?.argument
        else { throw StaticArrayExpansionError.noGenericType }
        
        let arrayType = TupleTypeSyntax(elements: TupleTypeElementListSyntax {
            for _ in 0..<count {
                TupleTypeElementSyntax(type: elementType)
            }
        })
        
        let constructor = TupleExprSyntax {
            for i in 0..<count {
                LabeledExprSyntax(expression: ExprSyntax("elements[\(literal: i)]"))
            }
        }
        
        let indices = (0..<count).map { TokenSyntax.identifier("i\($0)") }
        let indexCaseElements = EnumCaseElementListSyntax {
            for indexName in indices {
                EnumCaseElementSyntax(name: indexName)
            }
        }
        
        let subscriptSwitchPattern = SwitchCaseLabelSyntax {
            for (i, indexName) in indices.enumerated() {
                let indexPattern = ExpressionPatternSyntax(
                    expression: MemberAccessExprSyntax(name: indexName)
                )
                
                let reprPattern = TuplePatternSyntax {
                    for j in 0..<count {
                        if i == j {
                            TuplePatternElementSyntax(pattern: PatternSyntax("let x"))
                        } else {
                            TuplePatternElementSyntax(pattern: WildcardPatternSyntax())
                        }
                    }
                }
                
                SwitchCaseItemSyntax(pattern: TuplePatternSyntax {
                    TuplePatternElementSyntax(pattern: indexPattern)
                    TuplePatternElementSyntax(pattern: reprPattern)
                })
            }
        }
        
        return ["""
        struct \(name): ExpressibleByArrayLiteral {
            var repr: \(arrayType)
        
            enum Index: CaseIterable, Int {
                case \(indexCaseElements)
            }
        
            subscript(_ index: Index) -> \(elementType) {
                switch (index, repr) {
                    \(subscriptSwitchPattern)
                    return x
                }
            }
            
            subscript(safe intIndex: Int) -> \(elementType)? {
                guard let index = Index(rawValue: index) else { return nil }
                return self[index]
            }
        
            subscript(_ intIndex: Int) -> \(elementType) {
                guard let value = self[safe: intIndex]
                else { preconditionFailure(
                    "Attempted to access a static array \(name) (size: \(literal: count)) with an integer index out of bounds (index: \\(intIndex))"
                ) }
            }
        
            typealias ArrayLiteralElement = \(elementType)
            init(arrayLiteral elements: \(elementType)...) {
                precondition(elements.count == \(literal: count), "Type \(name) (#StaticArray) can only be initialized with array literals with exact size of \(literal: count). Got a literal with \\(elements.count) elements")
                self.repr = \(constructor)
            }
        }
        """]
    }
}

extension String {
    func toInt() -> Int? { Int(self) }
}

@main
struct StaticArrayPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StaticArrayMacro.self
    ]
}
