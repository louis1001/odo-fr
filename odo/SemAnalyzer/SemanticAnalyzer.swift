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

            case .assignment(let lhs, let val):
                return try assignment(to: lhs, val: val)
            case .variable(let name):
                return try variable(name: name)
            case .varDeclaration(let tp, let name, let initial):
                return try varDeclaration(tp: tp, name: name, initial: initial)
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
        
        func assignment(to lhs: Node, val: Node) throws -> NodeResult {
            if let sym = try getSymbolFromNode(lhs) {
                guard let _ = sym.type, !sym.isType else {
                    // Error! Invalid assignment
                    throw OdoException.SemanticError(message: "Invalid assignment to symbol `\(sym.name)`.")
                }
                
                let newValue = try visit(node: val)
                
                guard let newType = newValue.tp else {
                    throw OdoException.SemanticError(message: "Invalid assignment to symbol `\(sym.name)`. Operation doesn't provide a value.")
                }
                
                if !sym.isInitialized {
                    if sym.type == .anyType {
                        sym.type = newType
                    }
                    
                    sym.isInitialized = true
                }
                
                if !counts(type: newType, as: sym.type!) {
                    throw OdoException.TypeError(
                        message: "Invalid assignment, variable `\(sym.name)` expected value of type `\(sym.type!.name)` but recieved `\(newValue.tp?.name ?? "no value")`")
                }
                
                // TODO: Set constantness and side effects for symbol
            } else {
                // Error!
                throw OdoException.NameError(message: "Assignment to unknown variable.")
            }
            
            return .nothing
        }
        
        func variable(name: Token) throws -> NodeResult {
            guard let sym = currentScope[name.lexeme] else {
                throw OdoException.NameError(message: "Variable called `\(name.lexeme!)` not defined.")
            }
            
            if !sym.hasBeenChecked {
                // TODO: consumeLazy
            }
            
            if sym.isInitialized {
                // TODO: Constantness info
                return NodeResult(tp: sym.type)
            }
            
            throw OdoException.ValueError(message: "Using variable `\(sym.name)` when is hasn't been initialized.")
        }
        
        func varDeclaration(tp: Node, name: Token, initial: Node) throws -> NodeResult {
            if let _ = currentScope[name.lexeme] {
                throw OdoException.NameError(message: "Variable called `\(name.lexeme ?? "??")` already exists.")
            }
            
            guard let type = try getSymbolFromNode(tp) else {
                throw OdoException.NameError(message: "Unknown type `\(tp)`")
            }
            
            guard let type = type as? TypeSymbol else {
                throw OdoException.TypeError(message: "Symbol `\(type.name)` is not a valid type.")
            }
            
            if !type.hasBeenChecked {
                // TODO: consume lazy
            }
            
            let newVar = VarSymbol(name: name.lexeme, type: type)

            switch initial {
            case .noOp:
                break
            default:
                let newValue = try visit(node: initial)
                
                guard let newType = newValue.tp else {
                    throw OdoException.ValueError(message: "Initial expression for declaration of `\(newVar.name)` does not provide a value.")
                }
                
                if !newType.hasBeenChecked {
                    // TODO: consume lazy
                }
                
                guard counts(type: newType, as: type) else {
                    throw OdoException.TypeError(message: "Invalid declaration, variable `\(newVar.name)` expected value of type `\(type.name)` but recieved `\(newType.name)`")
                }
                
                if type == .anyType {
                    newVar.type = newType
                }
                
                // TODO: Update constantness
            
                newVar.isInitialized = true
                
            }
            
            currentScope.addSymbol(newVar)
            
            return .nothing
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
        
        func counts(type left: TypeSymbol, as right: TypeSymbol) -> Bool {
            if right == .anyType { return true }
//            if left is null and right a class type { return true }
            
            if left.isNumeric && right.isNumeric { return true }
            
            if left == right { return true }
            
            var curr: TypeSymbol = left
            while let parent = curr.type {
                if parent == right { return true }
                curr = parent
            }
            
            return false
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
