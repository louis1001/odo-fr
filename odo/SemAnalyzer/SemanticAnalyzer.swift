//
//  SemanticAnalyzer.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    public class SemanticAnalyzer {
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
            case .text(_):
                return NodeResult(tp: .textType)
            case .true, .false:
                return NodeResult(tp: .boolType)
            case .arithmeticOp(let lhs, let op, let rhs):
                return try arithmeticOp(lhs: lhs, op: op,rhs: rhs)
            case .logicOp(let lhs, let op, let rhs):
                return try logicOp(lhs: lhs, op: op,rhs: rhs)
            case .equalityOp(let lhs, let op, let rhs):
                return try equalityOp(lhs: lhs, op: op, rhs: rhs)
            case .ternaryOp(let condition, let trueCase, let falseCase):
                return try ternaryOp(condition: condition, true: trueCase, false: falseCase)

            case .assignment(let lhs, let val):
                return try assignment(to: lhs, val: val)
            case .variable(let name):
                return try variable(name: name)
            case .varDeclaration(let tp, let name, let initial):
                return try varDeclaration(tp: tp, name: name, initial: initial)
                
            case .functionCall(let expr, let name, let args):
                return try functionCall(expr: expr, name: name, args: args)
                
            case .loop(let body):
                return try loop(body: body)
            case .while(let cond, let body):
                return try vWhile(cond: cond, body: body)
            case .forange(let id, let first, let second, let body, let rev):
                return try forange(id: id, first: first, second: second, body: body, rev: rev)
            case .noOp:
                return .nothing
            }
        }
        
        func block(body: [Node]) throws -> NodeResult {
            let tempScope = currentScope
            currentScope = SymbolTable("block_scope", parent: currentScope)
            for statement in body {
                try visit(node: statement)
            }
            currentScope = tempScope
            
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
            
            if left == .textType || right == .textType {
                return try arithmeticWithTexts(lhs: left, op: op, rhs: right)
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
        
        func arithmeticWithTexts(lhs: TypeSymbol, op: Token, rhs: TypeSymbol) throws -> NodeResult {
            switch op.type {
            case .plus:
                return NodeResult(tp: .textType)
            case .mul:
                if rhs == .intType {
                    return NodeResult(tp: .textType)
                } else {
                    throw OdoException.TypeError(message: "Text can only be multiplied by an integer.")
                }
            default:
                throw OdoException.SemanticError(message: "Invalid operation between texts `\(op)`")
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
        
        func equalityOp(lhs: Node, op: Token, rhs: Node) throws -> NodeResult {
            switch op.type {
            case .equals, .notEquals:
                break
            default:
                throw OdoException.SemanticError(message: "Internal. Invalid operator \(op) for equality expression")
            }
            
            let lhs = try visit(node: lhs)
            guard lhs.tp != nil else {
                throw OdoException.ValueError(message: "Left operand in equality operator \(op) must return a value.")
            }
            let rhs = try visit(node: rhs)
            guard rhs.tp != nil else {
                throw OdoException.ValueError(message: "Right operand in equality operator \(op) must return a value.")
            }
            
            if !counts(type: lhs.tp!, as: rhs.tp!) || !counts(type: rhs.tp!, as: lhs.tp!) {
                throw OdoException.TypeError(
                    message: "Invalid equality operation `\(op)`. Value have incompatible types `\(lhs.tp!)` and `\(rhs.tp!)`")
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
            if let _ = currentScope[name.lexeme, false] {
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
        
        func functionCall(expr: Node, name: Token?, args: [Node]) throws -> NodeResult {
            let function = try getSymbolFromNode(expr)
            
            guard let _ = function?.type as? FunctionTypeSymbol else {
                throw OdoException.TypeError(message: "Invalid function call. Value of type `\(function?.name ?? "")` is not a function.")
            }
            
            switch function {
            case let native as NativeFunctionSymbol:
                switch native.argCount {
                case .none:
                    guard args.isEmpty else {
                        throw OdoException.ValueError(
                            message: "Function `\(native.name)` takes no arguments."
                        )
                    }
                case .any:
                    break
                case .some(let x):
                    guard args.count == x else {
                        throw OdoException.ValueError(
                            message: "Function `\(native.name)` takes `\(x)` arguments."
                        )
                    }
                case .someOrLess(let x):
                    guard args.count <= x else {
                        throw OdoException.ValueError(
                            message: "Function `\(native.name)` takes `\(x)` arguments or less."
                        )
                    }
                }
                
                let result = try native.semanticTest(args, self)
                
                return NodeResult(tp: result)
//            case let scripted as ScriptFunctionSymbol:
//                break
            default:
                break
            }
            
            return .nothing
        }
        
        func ternaryOp(condition: Node, true trueCase: Node, false falseCase: Node) throws -> NodeResult {
            
            let cond = try visit(node: condition)
            
            if cond.tp != .boolType {
                throw OdoException.TypeError(message: "Condition of ternary expression must be boolean.")
            }
            
            let trueResult = try visit(node: trueCase)
            let falseResult = try visit(node: falseCase)
            
            guard trueResult.tp != nil else {
                throw OdoException.ValueError(message: "True branch in ternary operator must have a type (provide value).")
            }
            
            guard falseResult.tp != nil else {
                throw OdoException.ValueError(message: "False branch in ternary operator must have a type (provide value).")
            }
            
            if !counts(type: trueResult.tp!, as: falseResult.tp!) {
                throw OdoException.TypeError(message: "Both branches in ternary operator must return the same type.")
            }
            
            // TODO: Return the type with higher hierarchy
            return NodeResult(tp: falseResult.tp)
        }
        
        func loop(body: Node) throws -> NodeResult {
            try visit(node: body)
            return .nothing
        }
        
        func vWhile(cond: Node, body: Node) throws -> NodeResult {
            let cond = try visit(node: cond)
            
            if cond.tp != .boolType {
                throw OdoException.TypeError(message: "Condition expression of while statement must be boolean.")
            }
            
            try visit(node: body)
            
            return .nothing
        }
        
        func forange(id: Token?, first: Node, second: Node?, body: Node, rev: Bool) throws -> NodeResult {
            let forangeScope = SymbolTable("forange:loop", parent: currentScope)
            currentScope = forangeScope
            
            let first = try visit(node: first)
            guard first.tp != nil else {
                throw OdoException.ValueError(message: "Range value in `forange` must have a type (provide value).")
            }
            
            guard first.tp!.isNumeric else {
                throw OdoException.TypeError(message: "Values defining the range of forange statement have to be numerical")
            }
            
            if let second = second {
                let second = try visit(node: second)
                guard second.tp != nil else {
                    throw OdoException.ValueError(message: "Range value in `forange` must have a type (provide value).")
                }
                
                guard second.tp!.isNumeric else {
                    throw OdoException.TypeError(message: "Values defining the range of forange statement have to be numerical")
                }
            }
            
            if let usingId = id {
                let _ = try varDeclaration(
                    tp: .variable(Token(type: .identifier, lexeme: "int")),
                    name: usingId,
                    initial: .noOp
                )

                currentScope[usingId.lexeme, false]!.isInitialized = true
            }
            
            try visit(node: body)
            
            currentScope = forangeScope.parent!
            
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
        
        public func validate(arg: Node, type: TypeSymbol) throws {
            let argument = try visit(node: arg)

            guard let argType = argument.tp, counts(type: argType, as: type) else {
                throw OdoException.TypeError(message: "Function takes an argument of type `\(type.name)`.")
            }
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
