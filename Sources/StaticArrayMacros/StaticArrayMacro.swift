import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

func plural(ofTypeDeclKeyword keyword: TokenKind?) -> String? {
    switch (keyword) {
    case .keyword(.class): "classes"
    case .keyword(.enum): "enums"
    case .keyword(.actor): "actors"
    case .keyword(.struct): "structs"
    case .keyword(.extension): "extensions"
    case .keyword(.protocol): "protocols"
    default: nil
    }
}

public enum SAExpansionError: CustomStringConvertible, Error {
    case invalidName, invalidCount(got: ExprSyntax?), noGenericType, attachedToANonStructType(keyword: TokenSyntax?)
    
    public var description: String {
        switch self {
        case .invalidName: "#StaticArray expected to receive an argument `named:` which should be a string literal"
        case .invalidCount(got: nil): "#StaticArray expected to receive an argument `count:` which should be a positive number literal"
        case .invalidCount(got: let got?): "Count of #StaticArray should be at least 2. Got \(got)"
        case .noGenericType: "#StaticArray requires setting an element type explicitly using swift's generics syntax, aka: #StaticArray<ElementType>(count: 5, named: \"MyArray\")"
        case .attachedToANonStructType(keyword: let keyword):
            if let plural = plural(ofTypeDeclKeyword: keyword?.tokenKind) {
                "@StaticArray can only be declared on the struct types, not \(plural)"
            } else {
                "@StaticArray can only be declared on the struct types"
            }
        }
    }
    
    var syntaxNode: (any SyntaxProtocol)? {
        switch self {
        case .invalidCount(got: let node):
            return node
        case .attachedToANonStructType(keyword: let node):
            return node
        default:
            return nil
        }
    }
}

public struct StaticArrayMacro: DeclarationMacro, MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
        debugPrint((
            func: "expansion(of:attachedTo:providingExtensionsOf:conformingTo:in:)",
            node: node,
            attachedTo: declaration,
            providingExtensionsOf: type,
            conformingTo: protocols,
            in: context
        ))
        return []
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try providingErrorDiagnostic(in: context) {
            try expansion(of: node, providingMembersOf: declaration)
        }
    }
        
    private static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax
    ) throws -> [DeclSyntax] {
        debugPrint((
            func: "expansion(of:providingMembersOf:conformingTo:in:)",
            of: node,
            providingMembersOf: declaration
        ))
        
        let structDecl = try asStructDecl(fromDeclarationGroup: declaration)
        let typeName = structDecl.name.trimmed
        let count = try count(fromAttributeArguments: node.arguments)
        let elementType = try elementType(fromAttributeName: node.attributeName)
        let arrayType = arrayType(of: elementType, count: count)

        return ["""
        var staticArrayStorage: \(arrayType)
        
        init(_ repr: \(arrayType)) {
            self.staticArrayStorage = repr
        }
        
        \(sequenceInit(elementType: elementType, count: count, typeName: typeName))
        
        init(from sequence: some Sequence<\(elementType)>, fillingMissingWith defaultValue: \(elementType)) {
            var iter = sequence.makeIterator()
            self.staticArrayStorage = \(tupleConstructorOfIterNextsWithDefaults(count: count))
        }
        
        \(exactlySizedSequenceInit(elementType: elementType, count: count, typeName: typeName))
        
        enum Index: Int, CaseIterable {
            case \(indexCaseElements(count: count))
        }
        """]
    }
    
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try providingErrorDiagnostic(in: context) {
            try expansion(of: node)
        }
    }
    
    
    private static func expansion(of node: some FreestandingMacroExpansionSyntax) throws -> [DeclSyntax] {
        guard let nameStr = node.argumentList
            .first(where: { $0.label?.text == "named" })?
            .expression
            .as(StringLiteralExprSyntax.self)?
            .representedLiteralValue
        else { throw SAExpansionError.invalidName }
        let name = TokenSyntax.identifier(nameStr)
        
        let count = try count(fromArgumentList: node.argumentList)
        let elementType = try elementType(fromGenericArgumentClause: node.genericArgumentClause)
        let arrayType = arrayType(of: elementType, count: count)
        
        let arrayLiteralConstructor = TupleExprSyntax {
            for i in 0..<count {
                LabeledExprSyntax(expression: ExprSyntax("elements[\(literal: i)]"))
            }
        }
        
        let initArgNames = identifierList(count: count, prefix: "v")
        
        let descriptionSegments = StringLiteralSegmentListSyntax {
            StringSegmentSyntax(content: .stringSegment("["))
            ExpressionSegmentSyntax {
                LabeledExprSyntax(expression: ExprSyntax("staticArrayStorage.0"))
            }
            for i in 1..<count {
                StringSegmentSyntax(content: .stringSegment(", "))
                ExpressionSegmentSyntax {
                    LabeledExprSyntax(expression: ExprSyntax("staticArrayStorage.\(raw: i)"))
                }
            }
            StringSegmentSyntax(content: .stringSegment("]"))
        }
        let descritpionString = StringLiteralExprSyntax(
            openingQuote: .stringQuoteToken(),
            segments: descriptionSegments,
            closingQuote: .stringQuoteToken()
        )
        
        return ["""
        struct \(name): UnsafeStaticArrayProtocol, ExpressibleByArrayLiteral, CustomStringConvertible {
            var staticArrayStorage: \(arrayType)
        
            typealias Element = \(elementType)
        
            init(_ repr: \(arrayType)) {
                self.staticArrayStorage = repr
            }
        
            init(\(functionArgList(argumentNames: initArgNames, elementType: elementType))) {
                self.staticArrayStorage = \(tupleConstructor(argumentNames: initArgNames))
            }
        
            \(sequenceInit(elementType: elementType, count: count, typeName: name))
        
            init(from sequence: some Sequence<\(elementType)>, fillingMissingWith defaultValue: \(elementType)) {
                var iter = sequence.makeIterator()
                self.staticArrayStorage = \(tupleConstructorOfIterNextsWithDefaults(count: count, additionalIdentation: 4))
            }
        
            \(exactlySizedSequenceInit(elementType: elementType, count: count, typeName: name))
        
            enum Index: Int, CaseIterable {
                case \(indexCaseElements(count: count))
            }
        
            var description: String { \(descritpionString) }
        
            typealias ArrayLiteralElement = \(elementType)
            init(arrayLiteral elements: \(elementType)...) {
                precondition(elements.count == \(literal: count), "Type \(name) (#StaticArray) can only be initialized with array literals with exact size of \(literal: count). Got a literal with \\(elements.count) elements")
                self.staticArrayStorage = \(arrayLiteralConstructor)
            }
        }
        """]
    }
    
    private static func providingErrorDiagnostic<T>(
        in context: some MacroExpansionContext,
        _ body: () throws -> [T]
    ) rethrows -> [T] {
        do {
            return try body()
        } catch let error as SAExpansionError {
            if let node = error.syntaxNode {
                context.addDiagnostics(from: error, node: node)
                return []
            } else {
                throw error
            }
        }
    }
    
    static func count(fromArgumentList argList: LabeledExprListSyntax) throws -> Int {
        guard let countArg = argList
            .first(where: { $0.label?.text == "count" })?
            .expression
        else { throw SAExpansionError.invalidCount(got: nil) }
        guard let count = countArg
            .as(IntegerLiteralExprSyntax.self)?
            .literal
            .text
            .toInt()
        else { throw SAExpansionError.invalidCount(got: countArg) }
        if count <= 1 {
            throw SAExpansionError.invalidCount(got: countArg)
        }
        return count
    }
    
    static func count(fromAttributeArguments arguments: AttributeSyntax.Arguments?) throws -> Int {
        guard let argList = arguments?.as(LabeledExprListSyntax.self) else {
            throw SAExpansionError.invalidCount(got: nil)
        }
        return try count(fromArgumentList: argList)
    }
    
    static func elementType(fromGenericArgumentClause clause: GenericArgumentClauseSyntax?) throws -> TypeSyntax {
        guard let elementType = clause?.arguments.first?.argument
        else { throw SAExpansionError.noGenericType }
        return elementType
    }
    
    static func elementType(fromAttributeName name: TypeSyntax) throws -> TypeSyntax {
        guard let genericClause = name.as(IdentifierTypeSyntax.self)?.genericArgumentClause
        else { throw SAExpansionError.noGenericType }
        return try elementType(fromGenericArgumentClause: genericClause)
    }
    
    static func arrayType(of elementType: TypeSyntax, count: Int) -> TupleTypeSyntax {
        return TupleTypeSyntax(elements: TupleTypeElementListSyntax {
            for (_, trivia) in withGap(0..<count) {
                TupleTypeElementSyntax(leadingTrivia: trivia, type: elementType)
            }
        })
    }

    static func identifierList(count: Int, prefix: String) -> [TokenSyntax] {
        return (0..<count).map { TokenSyntax.identifier("\(prefix)\($0)") }
    }
    
    static func withGap<Seq: Sequence>(_ items: Seq, inBetwee trivia: Trivia = .space) -> some Sequence<(item: Seq.Element, trivia: Trivia?)> {
        items.enumerated().map { (idx, item) in
            if idx == 0 { (item, nil) }
            else { (item, trivia) }
        }
    }
    
    static func indexCaseElements(count: Int) -> EnumCaseElementListSyntax {
        return EnumCaseElementListSyntax {
            for (indexName, trivia) in withGap(identifierList(count: count, prefix: "i")) {
                EnumCaseElementSyntax(leadingTrivia: trivia, name: indexName)
            }
        }
    }

    static func tupleConstructor(argumentNames: [TokenSyntax]) -> TupleExprSyntax {
        return TupleExprSyntax {
            for (argName, trivia) in withGap(argumentNames) {
                LabeledExprSyntax(leadingTrivia: trivia, expression: DeclReferenceExprSyntax(baseName: argName))
            }
        }
    }

    static func functionArgList(argumentNames: [TokenSyntax], elementType: TypeSyntax) -> FunctionParameterListSyntax {
        return FunctionParameterListSyntax {
            for argName in argumentNames {
                FunctionParameterSyntax(firstName: .wildcardToken(trailingTrivia: .space), secondName: argName, type: elementType)
            }
        }
    }
    
    static func missingTuplePattern(bindingNames: [TokenSyntax]) -> TuplePatternSyntax {
        TuplePatternSyntax {
            for (name, trivia) in withGap(bindingNames) {
                TuplePatternElementSyntax(leadingTrivia: trivia, pattern: PatternSyntax("\(name)?"))
            }
        }
    }

    static func sequenceInit(elementType: TypeSyntax, count: Int, typeName: TokenSyntax) -> DeclSyntax {
        let argNames = identifierList(count: count, prefix: "v")

        return """
        init(from sequence: some Sequence<\(elementType)>) {
            var iter = sequence.makeIterator()
            let items = \(tupleConstructorOfIterNexts(count: count))
            if case let \(missingTuplePattern(bindingNames: argNames)) = items {
                self.staticArrayStorage = \(tupleConstructor(argumentNames: argNames))
            } else {
                preconditionFailure("Couldn't construct \(typeName) from a sequnce, which contains less than \(raw: count) elements")
            }
        }
        """
    }
    
    static func tupleConstructorOfIterNexts(count: Int) -> TupleExprSyntax {
        let leadingTrivia = Trivia(pieces: [.newlines(1), .spaces(8)])
        
        return TupleExprSyntax {
            for _ in 0..<count - 1 {
                LabeledExprSyntax(
                    leadingTrivia: leadingTrivia,
                    expression: ExprSyntax("iter.next()")
                )
            }
            LabeledExprSyntax(
                leadingTrivia: leadingTrivia,
                expression: ExprSyntax("iter.next()"),
                trailingTrivia: Trivia(pieces: [.newlines(1), .spaces(4)])
            )
        }
    }
    
    static func tupleConstructorOfIterNextsWithDefaults(count: Int, additionalIdentation: Int = 0) -> TupleExprSyntax {
        let leadingTrivia = Trivia(pieces: [.newlines(1), .spaces(8 + additionalIdentation)])
        
        return TupleExprSyntax {
            for _ in 0..<count - 1 {
                LabeledExprSyntax(
                    leadingTrivia: leadingTrivia,
                    expression: ExprSyntax("iter.next() ?? defaultValue")
                )
            }
            LabeledExprSyntax(
                leadingTrivia: leadingTrivia,
                expression: ExprSyntax("iter.next() ?? defaultValue"),
                trailingTrivia: Trivia(pieces: [.newlines(1), .spaces(4 + additionalIdentation)])
            )
        }
    }
    
    static func tuplePatternOfOptionalWildcards(count: Int) -> TuplePatternSyntax {
        TuplePatternSyntax {
            for (_, trivia) in withGap(0..<count) {
                TuplePatternElementSyntax(leadingTrivia: trivia, pattern: PatternSyntax("_?"))
            }
        }
    }
    
    static func exactlySizedSequenceInit(elementType: TypeSyntax, count: Int, typeName: TokenSyntax) -> DeclSyntax {
        let variableNames = identifierList(count: count, prefix: "v")
        
        let fromExactSeqInitExactPattern = TuplePatternSyntax {
            for (name, trivia) in withGap(variableNames) {
                TuplePatternElementSyntax(leadingTrivia: trivia, pattern: PatternSyntax("\(name)?"))
            }
            TuplePatternElementSyntax(
                leadingTrivia: .space,
                pattern: ExpressionPatternSyntax(
                    expression: NilLiteralExprSyntax()
                )
            )
        }
        
        return """
        init(fromExactlySized sequence: some Sequence<\(elementType)>) {
            var iter = sequence.makeIterator()
            let items = \(tupleConstructorOfIterNexts(count: count + 1))
            switch items {
            case let \(fromExactSeqInitExactPattern):
                self.staticArrayStorage = \(tupleConstructor(argumentNames: variableNames))
            case \(tuplePatternOfOptionalWildcards(count: count + 1)):
                preconditionFailure("Couldn't construct \(typeName) from an exactly sized sequence, which contains more than \(raw: count) elements")
            default:
                preconditionFailure("Couldn't construct \(typeName) from an exactly sized sequnce, which contains less than \(raw: count) elements")
            }
        }
        """
    }
    
    static func asStructDecl(fromDeclarationGroup decl: some DeclGroupSyntax) throws -> StructDeclSyntax {
        if case let structDecl as StructDeclSyntax = decl {
            return structDecl
        }
        
        let invalidKeyword: TokenSyntax? = switch decl {
        case let enumDecl as EnumDeclSyntax: enumDecl.enumKeyword
        case let classDecl as ClassDeclSyntax: classDecl.classKeyword
        case let protocolDecl as ProtocolDeclSyntax: protocolDecl.protocolKeyword
        case let extensionDecl as ExtensionDeclSyntax: extensionDecl.extensionKeyword
        case let actorDecl as ActorDeclSyntax: actorDecl.actorKeyword
        default: nil
        }
        throw SAExpansionError.attachedToANonStructType(keyword: invalidKeyword)
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
