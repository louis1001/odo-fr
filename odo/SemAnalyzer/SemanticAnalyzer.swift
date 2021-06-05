//
//  SemanticAnalyzer.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    class SemanticAnalyzer {
        let interpreter: Interpreter
        let globalScope: SymbolTable
        let replScope: SymbolTable
        
        var currentScope: SymbolTable
        
        init(inter: Interpreter) {
            self.interpreter = inter
            globalScope = SymbolTable("semanticGlobalTable", parent: inter.globalTable)
            replScope = SymbolTable("semanticRepl", parent: globalScope)
            currentScope = globalScope
        }
        
        @discardableResult
        func visit(node: Node) throws -> NodeResult {
            switch node {
            case .block(let body):
                return try block(body: body)
            case .double(_):
                return NodeResult(tp: .doubleType)
            case .int(_):
                return NodeResult(tp: .intType)
            case .string(_):
                return NodeResult(tp: .stringType)
            case .true, .false:
                return NodeResult(tp: .boolType)
            case .arithmeticOp(let lhs, let op, let rhs):
                return try arithmeticOp(lhs: lhs, op: op,rhs: rhs)
            case .logicOp(let lhs, let op, let rhs):
                return try logicOp(lhs: lhs, op: op,rhs: rhs)
            case .noOp:
                return .nothing
            }
        }
        
        func block(body: [Node]) throws -> NodeResult {
            for statement in body {
                try visit(node: statement)
            }
            
            return .nothing
        }
        
        func arithmeticOp(lhs: Node, op: Token, rhs: Node) throws -> NodeResult {
            let lhs = try visit(node: lhs)
            let rhs = try visit(node: rhs)
            
            guard let left = lhs.tp else {
                throw OdoException.ValueError(message: "Left operand in binary operation has no value.")
            }
            
            guard let right = rhs.tp else {
                throw OdoException.ValueError(message: "Right operand in binary operation has no value.")
            }
            
            if left == .stringType || right == .stringType {
                return try arithmeticWithStrings(lhs: left, op: op, rhs: right)
            }
            
            guard left.isNumeric && right.isNumeric else {
                throw OdoException.ValueError(message: "Addition operation can only be used with numeric values.")
            }
            
            if left == .intType && right == .intType {
                return NodeResult(tp: .intType)
            } else {
                return NodeResult(tp: .doubleType)
            }
        }
        
        func arithmeticWithStrings(lhs: TypeSymbol, op: Token, rhs: TypeSymbol) throws -> NodeResult {
            switch op.type {
            case .plus:
                return NodeResult(tp: .stringType)
            case .mul:
                if rhs == .intType {
                    return NodeResult(tp: .stringType)
                } else {
                    throw OdoException.TypeError(message: "String can only be multiplied by an integer.")
                }
            default:
                throw OdoException.SemanticError(message: "Invalid operation between strings `\(op)`")
            }
        }
        
        func logicOp(lhs: Node, op: Token, rhs: Node) throws -> NodeResult {
            let lhs = try visit(node: lhs)
            let rhs = try visit(node: rhs)
            
            let operandInLogic = " operand in logic operation `\(op)`"
            
            guard lhs.tp != nil else {
                throw OdoException.ValueError(message: "Left \(operandInLogic) must return a value.")
            }
            
            guard rhs.tp != nil else {
                throw OdoException.ValueError(message: "Right \(operandInLogic) must return a value.")
            }
            
            guard lhs.tp == .boolType else {
                throw OdoException.TypeError(message: "Left \(operandInLogic) is not boolean. Has type \(lhs.tp!)")
            }
            
            guard rhs.tp == .boolType else {
                throw OdoException.TypeError(message: "Right \(operandInLogic) is not boolean. Has type \(rhs.tp!)")
            }
            
            switch op.type {
            case .and, .or:
                break
            default:
                throw OdoException.SemanticError(message: "Invalid logic operator `\(op)`")
            }
            
            return NodeResult(tp: .boolType)
        }
        
        func analyze(root: Node) throws {
            try visit(node: root)
        }
        
        @discardableResult
        func fromRepl(statement: Node) throws -> NodeResult{
            let tempScope = currentScope
            currentScope = replScope
            
            let result = try visit(node: statement)
            
            currentScope = tempScope
            return result
        }
    }
}
