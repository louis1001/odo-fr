//
//  SemanticAnalyzer.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    class SemanticAnalyzer {
        init() {
            
        }
        
        func visit(node: Node) throws -> NodeResult {
            switch node {
            case .TDouble(_):
                return NodeResult(tp: .doubleType)
            case .Integer(_):
                return NodeResult(tp: .intType)
            case .String(_):
                return NodeResult(tp: .stringType)
            case .True, .False:
                return NodeResult(tp: .boolType)
            case .ArithmeticOp(let lhs, let op, let rhs):
                return try arithmeticOp(lhs: lhs, op: op,rhs: rhs)
            case .NoOp:
                return NodeResult()
            }
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
            case .Plus:
                return NodeResult(tp: .stringType)
            case .Mul:
                if rhs == .intType {
                    return NodeResult(tp: .stringType)
                } else {
                    throw OdoException.TypeError(message: "String can only be multiplied by an integer.")
                }
            default:
                throw OdoException.SemanticError(message: "Invalid operation between strings `\(op.toString())`")
            }
        }
        
        func analyze(root: Node) throws {
            let _ = try visit(node: root)
        }
    }
}
