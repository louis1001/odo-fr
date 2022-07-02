//
//  SemanticAnalyzer.swift
//  
//
//  Created by Luis Gonzalez on 17/6/22.
//

import Foundation

extension Odo {
public class SemanticAnalyzer {
    var symbols: [Symbol]
    var currentScopeId: Int
    var scopes: [Scope]
    
    public init() {
        symbols = []
        let globalScope = Scope(id: 0)
        scopes = [globalScope]
        currentScopeId = globalScope.id
        
        let anyType = addSymbol(PrimitiveTypeSymbol("any")) as! TypeSymbol

        addSymbol(PrimitiveTypeSymbol("int", type: anyType.id))
        addSymbol(PrimitiveTypeSymbol("double", type: anyType.id))
        addSymbol(PrimitiveTypeSymbol("text", type: anyType.id))
        addSymbol(PrimitiveTypeSymbol("truth", type: anyType.id))
    }
    
    @discardableResult
    func addSymbol(_ symbol: Symbol) -> Symbol {
        symbol.id = symbols.count
        let scope = scopes[currentScopeId]
        symbols.append(symbol)
        scope.add(symbol.id)
        
        return symbol
    }

    func createScope(called: String) -> Int {
        let newScopeId = scopes.count
        let scope = Scope(id: newScopeId)

        scope.parentId = currentScopeId
        scopes.append(scope)

        return newScopeId
    }

    @discardableResult
    public func visit(node: Node) throws -> (NodeResult, CheckedAst) {
        switch node {
        case .int(let string):
            guard let n = Int(string) else {
                throw OdoException.TypeError(message: "Invalid integer literal")
            }
            return (NodeResult(.int), .int(n))
        case .double(let string):
            guard let n = Double(string) else {
                throw OdoException.TypeError(message: "Invalid floating point literal")
            }
            return (NodeResult(.double), .double(n))
        case .text(let txt):
            return (NodeResult(.text), .text(txt))
        case .true:
            return (NodeResult(.truth), .truth(true))
        case .false:
            return (NodeResult(.truth), .truth(false))
        case .break:
            return (NodeResult(), .break)
        case .continue:
            return (NodeResult(), .continue)
        case .block(let array):
            let nodes = try checkBlock(array)
            return (NodeResult(), .block(nodes))
        case .arithmeticOp(let lhs, let op, let rhs):
            return try checkArithmeticOp(lhs: lhs, op: op, rhs: rhs)
//        case .logicOp(let node, let token, let node):
//            <#code#>
//        case .equalityOp(let node, let token, let node):
//            <#code#>
//        case .relationalOp(let node, let token, let node):
//            <#code#>
//        case .ternaryOp(let node, let node, let node):
//            <#code#>
//        case .unaryOp(let token, let node):
//            <#code#>
        case .variable(let name):
            return try checkVariable(name: name)
        case .varDeclaration(let type, let name, let initial, let isConstant):
            return (
                NodeResult(),
                try checkVarDeclaration(type, name, initial, isConstant)
            )
        case .assignment(let target, let value):
            return (NodeResult(), try checkAssignment(target: target, value: value))
//        case .functionDeclaration(let string, let array, let optional, let node):
//            <#code#>
//        case .functionBody(let array):
//            <#code#>
//        case .functionCall(let node, let optional, let array):
//            <#code#>
//        case .returnStatement(let optional):
//            <#code#>
//        case .module(let string, let array):
//            <#code#>
        case .enum(let name, let cases):
           return (NodeResult(), try checkEnum(name: name, cases: cases))
       case .staticAccess(let source, let query):
           return try checkStaticAccess(source: source, query: query)
//        case .ifStatement(let node, let node, let optional):
//            <#code#>
//        case .loop(let node):
//            <#code#>
//        case .while(let node, let node):
//            <#code#>
//        case .forange(let optional, let node, let optional, let node, let bool):
//            <#code#>
//        case .functionType(let array, let optional):
//            <#code#>
        case .noOp:
            return (NodeResult(), .noOp)
        default:
            // TODO: Add all nodes
            fatalError("No handler for `\(node)`")
        }
    }
    
    func checkBlock(_ nodes: [Node]) throws -> [CheckedAst]{
        var result: [CheckedAst] = []

        let blockScope = createScope(called: "block_scope")
        let prevScope = currentScopeId
        currentScopeId = blockScope
        
        // Setup a scope
        for node in nodes {
            let (_, tree) = try visit(node: node)
            result.append(tree)
        }
        
        // TODO: Maybe block can return something by default
        currentScopeId = prevScope
        
        return result
    }

    func checkArithmeticOp(lhs: Node, op: Token, rhs: Node) throws -> (NodeResult, CheckedAst) {
        let (lhsResult, lhsChecked) = try visit(node: lhs)
        let (rhsResult, rhsChecked) = try visit(node: rhs)

        guard lhsResult.typeId != nil,  lhsResult.typeId == rhsResult.typeId else {
            throw OdoException.TypeError(message: "Operands of arithmetic operation need to be of the same type")
        }

        switch op.type {
            case .plus, .minus, .mul, .div:
                break

            default:
                throw OdoException.SemanticError(message: "Invalid operator for arithmetic operation: \(op.description)")
        }

        return (NodeResult(lhsResult.typeId!), .arithmeticOp(lhsChecked, op, rhsChecked))
    }

    func checkVariable(name: String) throws -> (NodeResult, CheckedAst) {
        guard let sym = try getSymbol(called: name) else {
            throw OdoException.NameError(message: "Unknown symbol `\(name)` in scope") 
        }

        return (
            NodeResult(sym.type ?? 0),
            .variable(name)
        )
    }
    
    func checkVarDeclaration(_ type: Node?, _ name: String, _ initial: Node?, _ isConstant: Bool) throws -> CheckedAst {
        var typeSymbol: TypeSymbol? = nil
        if let type = type {
            guard let typeSym = try getSymbol(from: type) else {
                throw OdoException.NameError(message: "Invalid type for variable declaration")
            }
            
            typeSymbol = typeSym as? TypeSymbol
        }
        
        if let _ = try getSymbol(called: name, nested: false) {
            throw OdoException.NameError(message: "Redeclaration of variable `\(name)`")
        }

        var initialChecked: CheckedAst? = nil
        if let initial = initial {
            let (result, val) = try visit(node: initial)

            guard let initialType = result.typeId else {
                throw OdoException.ValueError(message: "Invalid initialization. Needs to return a value")
            }
            initialChecked = val
            
                // Counts as?
            if let typeSymbol = typeSymbol {
                guard typeCounts(initialType, as: typeSymbol.id) else {
                    throw OdoException.TypeError(message: "Invalid initialization for var of type `\(typeSymbol.name)`")
                }
            } else {
                typeSymbol = symbols[result.typeId ?? 0] as? TypeSymbol
            }
        }

        let newSymbol = VarSymbol(name, type: typeSymbol?.id ?? 0)
        newSymbol.isConstant = isConstant
        addSymbol(newSymbol)
        
        return .varDeclaration(typeSymbol?.id ?? 0, name, initialChecked, isConstant)
    }
    
    func checkAssignment(target: Node, value: Node) throws -> CheckedAst {
        guard let targetSymbol = try getSymbol(from: target) else {
            throw OdoException.NameError(message: "Invalid assignment to unknown symbol")
        }

        guard !targetSymbol.isConstant else {
            throw OdoException.SemanticError(message: "Invalid reassignment to constant") // FIXME: Check for uninitialized constant first
        }
        
        guard let typeId = targetSymbol.type else {
            fatalError("Unreachable.")
        }
        
        let (valueResult, valueChecked) = try visit(node: value)
        
        guard let valueTypeId = valueResult.typeId else {
            throw OdoException.ValueError(message: "Invalid assignment. Doesn't provide a new value.")
        }
        
        guard typeCounts(valueTypeId, as: typeId) else {
            throw OdoException.TypeError(message: "Invalid type for assignment")
        }
        
        let (_, checkedType) = try visit(node: target)
        
        return .assignment(checkedType, valueChecked)
    }

    func checkEnum(name: String, cases: [String]) throws -> CheckedAst {
        if let _ = try getSymbol(called: name, nested: false) {
            throw OdoException.NameError(message: "Redeclaration of variable `\(name)`")
        }

        let enumType = EnumTypeSymbol(name)
        addSymbol(enumType)

        let prevScopeId = currentScopeId
        enumType.associatedScopeId = createScope(called: "enum_\(name)_scope")
        currentScopeId = enumType.associatedScopeId!

        for name in cases {
            let caseSymbol = EnumSymbol(name, type: enumType.id)
            addSymbol(caseSymbol)
        }

        currentScopeId = prevScopeId

        return .noOp // TODO: Maybe enums can contain more than the case definitions
    }

    func checkStaticAccess(source: Node, query: String) throws -> (NodeResult, CheckedAst) {
        guard let symbol = try getSymbol(from: .staticAccess(source, query)) else {
            throw OdoException.NameError(message: "Unknown symbol `\(query)` in static access")
        }

        return (NodeResult(symbol.type ?? 0), .symbolAccess(symbol.id))
    }

    func getSymbolFromId(_ id: Int, inScope scopeId: Int, andParents: Bool = true) -> Symbol? {
        let scope = scopes[scopeId]

        if scope.symbols.contains(where: { $0 == id }) {
            return symbols[id]
        }

        if andParents, let parentScope = scope.parentId {
            return getSymbolFromId(id, inScope: parentScope)
        }

        return nil
    }
    
    func getSymbol(from node: Node) throws -> Symbol? {
        switch node {
        case .variable(let name):
            let sym = try getSymbol(called: name)
            
            return sym
        case .staticAccess(let source, let name):
            guard let sym = try getSymbol(from: source) else {
                return nil
            }

            switch sym {
                case let enumType where enumType is EnumTypeSymbol:
                    guard let scopeId = enumType.associatedScopeId else {
                        fatalError("Unreachable")
                    }
                    let scope = scopes[scopeId]

                    return getSymbol(called: name, inScope: scope, nested: false)
                // ...
                default:
                    throw OdoException.SemanticError(message: "Invalid static access")
            }
        default:
            throw OdoException.SemanticError(message: "Cannot get symbol from node")
        }
    }
    
    func getSymbol(called name: String, nested: Bool = true) throws -> Symbol? {
        let scope = scopes[currentScopeId]
        
        return getSymbol(called: name, inScope: scope, nested: nested)
    }
    
    func getSymbol(called name: String, inScope scope: Scope, nested: Bool) -> Symbol? {
        for symbol in scope.symbols {
            let sym = symbols[symbol]
            if sym.name == name {
                return sym
            }
        }
        
        if nested, let parentScopeId = scope.parentId {
            let parentScope = scopes[parentScopeId]
            return getSymbol(called: name, inScope: parentScope, nested: nested)
        }
        
        return nil
    }

    func typeCounts(_ firstType: Int, as base: Int) -> Bool {
        var currentType: Int? = firstType
        while currentType != nil {
            if base == currentType {
                return true
            }

            let sym = symbols[currentType!]
            currentType = sym.type
        }

        return false
    }
}

}