//
//  Interpreter.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    public class Interpreter {
        let parser = Parser()
        lazy var semAn: SemanticAnalyzer = SemanticAnalyzer(inter: self)
        
        let globalTable: SymbolTable
        let replScope: SymbolTable
        
        var currentScope: SymbolTable
        
        public init() {
            globalTable = SymbolTable("globalTable")
            globalTable.addSymbol(.anyType)
            globalTable.addSymbol(.intType)
            globalTable.addSymbol(.doubleType)
            globalTable.addSymbol(.boolType)
            globalTable.addSymbol(.textType)
            globalTable.addSymbol(.nullType)
            
            currentScope = globalTable
            
            replScope = SymbolTable("repl", parent: globalTable)
            replScope.addSymbol(VarSymbol(name: "_", type: .anyType))
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
            case .text(let value):
                return TextValue(value: value.lexeme)
            case .true:
                return BoolValue(value: true)
            case .false:
                return BoolValue(value: false)
            case .arithmeticOp(let lhs, let op, let rhs):
                return try aritmeticOp(lhs: lhs, op: op, rhs: rhs)
            case .logicOp(let lhs, let op, let rhs):
                return try logicOp(lhs: lhs, op: op, rhs: rhs)
                
            case .assignment(let lhs, let val):
                return try assignment(to: lhs, val: val)
            case .variable(let name):
                return try variable(name: name)
            case .varDeclaration(let tp, let name, let initial):
                return try varDeclaration(tp: tp, name: name, initial: initial)
                
            case .ternaryOp(let condition, let trueCase, let falseCase):
                return try ternaryOp(condition: condition, true: trueCase, false: falseCase)
                
            case .noOp:
                break
            }
            
            return .null
        }
        
        func block(body: [Node]) throws -> Value {
            let tempScope = currentScope
            currentScope = SymbolTable("block_scope", parent: currentScope)
            var result: Value = .null
            for statement in body {
                result = try visit(node: statement)
            }
            currentScope = tempScope
            
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
            
            if leftVisited.type == .textType || rightVisited.type == .textType {
                return arithmeticWithTexts(lhs: leftVisited, op: op, rhs: rightVisited)
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
        
        func arithmeticWithTexts(lhs: Value, op: Token, rhs: Value) -> Value {
            switch op.type {
            case .plus:
                return TextValue(value: lhs.toText() + rhs.toText())
            case .mul:
                var result = ""
                let rightAsInt = (rhs as! IntValue).value
                for _ in 0..<rightAsInt {
                    result += lhs.toText()
                }
                return TextValue(value: result)
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
        
        func assignment(to lhs: Node, val: Node) throws -> Value {
            let varSym = try getSymbolFromNode(lhs) as! VarSymbol
            var newValue = try visit(node: val)
            
            if let _ = varSym.value {
                // If oldValue is copyable
                // Copy
            } else {
                // If newValue is copyable
                // Copy
                
                if varSym.type == .anyType {
                    varSym.type = newValue.type
                } else {
                    if varSym.type == .intType && newValue.type == .doubleType {
                        let internalValue = (newValue as! DoubleValue).asDouble()!
                        newValue = IntValue(value: Int(internalValue))
                    } else if varSym.type == .doubleType && newValue.type == .intType {
                        let internalValue = (newValue as! IntValue).asDouble()!
                        newValue = DoubleValue(value: internalValue)
                    }
                }
            }
            
            varSym.value = newValue
            
            return .null
        }
        
        func variable(name: Token) throws -> Value {
            let symbol = currentScope[name.lexeme] as! VarSymbol
            
            return symbol.value!
        }
        
        func varDeclaration(tp: Node, name: Token, initial: Node) throws -> Value {
            var type = try getSymbolFromNode(tp) as! TypeSymbol

            var initialValue: Value?
            switch initial {
            case .noOp:
                break
            default:
                initialValue = try visit(node: initial)
                
                if type == .anyType {
                    type = initialValue!.type
                } else {
                    if type == .intType && initialValue!.type == .doubleType {
                        let internalValue = (initialValue as! DoubleValue).asDouble()!
                        initialValue = IntValue(value: Int(internalValue))
                    } else if type == .doubleType && initialValue!.type == .intType {
                        let internalValue = (initialValue as! IntValue).asDouble()!
                        initialValue = DoubleValue(value: internalValue)
                    }
                }
            }
            
            let newVar: VarSymbol = VarSymbol(name: name.lexeme, type: type, value: initialValue)
            
            currentScope.addSymbol(newVar)
            
            return .null
        }
        
        func ternaryOp(condition: Node, true left: Node, false right: Node) throws -> Value {
            let cond = try visit(node: condition) as! BoolValue
            
            let leftSide = try visit(node: left)
            let rightSide = try visit(node: right)
            
            if cond.value {
                return leftSide
            } else {
                return rightSide
            }
        }
        
        func getSymbolFromNode(_ node: Node) throws -> Symbol? {
            // To improve later!
            
            switch node {
            case .variable(let name):
                return currentScope[name.lexeme, true]
            default:
                break
            }

            return Symbol(name: "", type: .anyType)
        }
        
        public func interpret(code: String) throws -> Value {
            try parser.setText(to: code)
            let root = try parser.program()
            
            try semAn.analyze(root: root)
            
            return try visit(node: root)
        }
        
        public func repl(code: String) throws -> Value {
            try parser.setText(to: code)
            let content = try parser.programContent()
            
            currentScope = replScope
            
            var result: Value = .null
            
            for statement in content {
                try semAn.fromRepl(statement: statement)
                result = try visit(node: statement)
            }
            
            currentScope = globalTable
            return result
        }
    }
}
