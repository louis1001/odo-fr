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
        
        @discardableResult
        func visit(node: Node) throws -> Value {
            switch node {
            case .block(let body):
                return try block(body: body)
            case .double(let value):
                return DoubleValue(value: Double(value.lexeme)!)
            case .int(let value):
                return IntValue(value: Int(value.lexeme)!)
            case .string(let value):
                return StringValue(value: value.lexeme)
            case .true:
                return BoolValue(value: true)
            case .false:
                return BoolValue(value: false)
            case .arithmeticOp(let lhs, let op, let rhs):
                return try aritmeticOp(lhs: lhs, op: op, rhs: rhs)
            case .logicOp(let lhs, let op, let rhs):
                return try logicOp(lhs: lhs, op: op, rhs: rhs)
            case .noOp:
                break
            }
            
            return .null
        }
        
        func block(body: [Node]) throws -> Value {
            var result: Value = .null
            for statement in body {
                result = try visit(node: statement)
            }
            
            return result
        }
        
        func aritmeticOp(lhs: Node, op: Token, rhs: Node) throws -> Value {
            var isDouble: Bool
            switch (lhs, rhs) {
            case (.int, .int):
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
            case .plus:
                result = lhs.asDouble()! + rhs.asDouble()!
            case .minus:
                result = lhs.asDouble()! - rhs.asDouble()!
            case .mul:
                result = lhs.asDouble()! * rhs.asDouble()!
            case .div:
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
            case .plus:
                return StringValue(value: lhs.toString() + rhs.toString())
            case .mul:
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
            case .and:
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
