//
//  Interpreter.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    public class Interpreter {
        let parser = Parser()
        let semAn: SemanticAnalyzer
        public init() {
            semAn = SemanticAnalyzer()
        }
        
        func visit(node: Node) throws -> Value {
            switch node {
            case .TDouble(let value):
                return DoubleValue(value: Double(value.lexeme)!)
            case .Integer(let value):
                return IntValue(value: Int(value.lexeme)!)
            case .String(let value):
                return StringValue(value: value.lexeme)
            case .True:
                return BoolValue(value: true)
            case .False:
                return BoolValue(value: false)
            case .ArithmeticOp(let lhs, let op, let rhs):
                return try aritmeticOp(lhs: lhs, op: op, rhs: rhs)
            case .LogicOp(let lhs, let op, let rhs):
                return try logicOp(lhs: lhs, op: op, rhs: rhs)
            case .NoOp:
                break
            }
            
            return .null
        }
        
        func aritmeticOp(lhs: Node, op: Token, rhs: Node) throws -> Value {
            var isDouble: Bool
            switch (lhs, rhs) {
            case (.Integer, .Integer):
                isDouble = false
            default:
                isDouble = true
            }

            let leftVisited = try visit(node: lhs)
            let rightVisited = try visit(node: rhs)
            
            if leftVisited.type == .stringType || rightVisited.type == .stringType {
                return arithmeticWithStrings(lhs: leftVisited, op: op, rhs: rightVisited)
            }
            
            let lhs = leftVisited as! PrimitiveValue
            let rhs = rightVisited as! PrimitiveValue
            
            let result: Double
            
            switch op.type {
            case .Plus:
                result = lhs.asDouble()! + rhs.asDouble()!
            case .Minus:
                result = lhs.asDouble()! + rhs.asDouble()!
            case .Mul:
                result = lhs.asDouble()! * rhs.asDouble()!
            case .Div:
                if rhs.asDouble()! == 0 {
                    throw OdoException.RuntimeError(message: "Attempted Division operation over zero.")
                }
                isDouble = true
                result = lhs.asDouble()! / rhs.asDouble()!
            default:
                return .null
            }

            if isDouble {
                return .primitive(result)
            } else {
                return .primitive(Int(result))
            }
        }
        
        func arithmeticWithStrings(lhs: Value, op: Token, rhs: Value) -> Value {
            switch op.type {
            case .Plus:
                return StringValue(value: lhs.toString() + rhs.toString())
            case .Mul:
                var result = ""
                let rightAsInt = (rhs as! IntValue).value
                for _ in 0..<rightAsInt {
                    result += lhs.toString()
                }
                return StringValue(value: result)
            default:
                fatalError("Invalid operation with strings. Ending program")
            }
        }
        
        func logicOp(lhs: Node, op: Token, rhs: Node) throws -> Value {
            let lhs = try visit(node: lhs) as! BoolValue
            let rhs = try visit(node: rhs) as! BoolValue
            
            switch op.type {
            case .And:
                return BoolValue(value: lhs.value && rhs.value)
            default:
                return BoolValue(value: lhs.value || rhs.value)
            }
        }
        
        public func interpret(code: String) throws -> Value {
            try parser.setText(to: code)
            let root = try parser.program()
            
            try semAn.analyze(root: root)
            
            return try visit(node: root)
        }
    }
}
