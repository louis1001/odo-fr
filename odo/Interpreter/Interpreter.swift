//
//  Interpreter.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    public class Interpreter {
        let parser = Parser()
        public init() {
            
        }
        
        func visit(node: Node) throws -> Value {
            switch node {
            case .TDouble(let value):
                return .NDouble(Double(value.lexeme)!)
            case .Integer(let value):
                return .Int(Int(value.lexeme)!)
            case .ArithmeticOp(let lhs, let op, let rhs):
                return try aritmeticOp(lhs: lhs, op: op, rhs: rhs)
            case .NoOp:
                break
            }
            
            return .Null
        }
        
        func aritmeticOp(lhs: Node, op: Token, rhs: Node) throws -> Value {
            var isDouble: Bool
            switch (lhs, rhs) {
            case (.Integer, .Integer):
                isDouble = false
            default:
                isDouble = true
            }

            let lhs = try visit(node: lhs)
            let rhs = try visit(node: rhs)
            
            let result: Double
            
            switch op.type {
            case .Plus:
                result = lhs.asNumeric()! + rhs.asNumeric()!
                
            case .Minus:
                result = lhs.asNumeric()! + rhs.asNumeric()!
            case .Mul:
                result = lhs.asNumeric()! * rhs.asNumeric()!
            case .Div:
                if rhs.asNumeric()! == 0 {
                    throw OdoException.RuntimeError(message: "Attempted Division operation over zero.")
                }
                isDouble = true
                result = lhs.asNumeric()! / rhs.asNumeric()!
            default:
                throw OdoException.SyntaxError(message: "Internal: Invalid arithmetic operator: \(op.type).")
            }

            if isDouble {
                return .NDouble(result)
            } else {
                return .Int(Int(result))
            }
        }
        
        public func interpret(code: String) throws -> Value {
            try parser.setText(to: code)
            let root = try parser.program()
            return try visit(node: root)
        }
    }
}
