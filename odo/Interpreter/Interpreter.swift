//
//  Interpreter.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//
import Foundation

extension Odo {
    struct CallStackFrame {}
    
    public class Interpreter {
        let parser = Parser()
        lazy var semAn: SemanticAnalyzer = SemanticAnalyzer(inter: self)
        
        let globalTable: SymbolTable
        let replScope: SymbolTable
        
        var currentScope: SymbolTable
        
        static let maxCallDepth: UInt = 600
        var callStack: [CallStackFrame] = []
        
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
            
            addNativeFunction("write", takes: .any) { values, _ in
                for val in values {
                    print(val.toText(), terminator: "")
                }
                return .null
            }
            
            addNativeFunction("writeln", takes: .any) { values, _ in
                for val in values {
                    print(val.toText(), terminator: "")
                }
                print()
                return .null
            }
            
            addNativeFunction("pow", takes: .someOrLess(2)) { args, _ in
                let arg1 = (args.first! as! PrimitiveValue).asDouble()!
                let power: Double
                
                if args.count > 1 {
                    power = (args[1] as! PrimitiveValue).asDouble()!
                } else {
                    power = 2
                }

                return DoubleValue(value: pow(arg1, power))
            } validation: { args, semAn in
                try semAn.validate(arg: args.first!, type: .doubleType)

                if args.count > 1 {
                    try semAn.validate(arg: args[1], type: .doubleType)
                }
                return .doubleType
            }
        }
        
        /// Create a function accessible from runtime Odo code
        /// that executes native swift. You should make sure that yout validation
        /// is as thourough as possible.
        /// - Parameters:
        ///   - name: The name of the symbol from which this function can be accessed
        ///   - body: The closure that is executed. It takes it's arguments as [Value]
        ///   - validation: The semantic validation of arguments and return type, recieves the list of Node and the Semantic analyzer.
        ///   Preferably gives static return type for all calls.
        public func addNativeFunction(
            _ name: String,
            takes args: NativeFunctionSymbol.ArgType = .none,
            body: @escaping ([Value], Interpreter) throws -> Value,
            validation: (([Node], SemanticAnalyzer) throws -> TypeSymbol?)? = nil) {
            
            let functionSymbol = NativeFunctionSymbol(name: name, takes: args, validation: validation)
            globalTable.addSymbol(functionSymbol)
            
            let functionValue = NativeFunctionValue(body: body)
            functionSymbol.body = functionValue
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
            case .equalityOp(let lhs, let op, let rhs):
                return try equalityOp(lhs: lhs, op: op, rhs: rhs)
            case .relationalOp(let lhs, let op, let rhs):
                return try relationalOp(lhs: lhs, op: op, rhs: rhs)
            case .ternaryOp(let condition, let trueCase, let falseCase):
                return try ternaryOp(condition: condition, true: trueCase, false: falseCase)
                
            case .assignment(let lhs, let val):
                return try assignment(to: lhs, val: val)
            case .variable(let name):
                return try variable(name: name)
            case .varDeclaration(let tp, let name, let initial):
                return try varDeclaration(tp: tp, name: name, initial: initial)
                
            case .functionBody(let args):
                return try functionBody(body: args)
            case .functionDeclaration(let name, let args, let ret, let body):
                return try functionDeclaration(name: name, args: args, returns: ret, body: body)
            case .functionCall(let expr, let name, let args):
                return try functionCall(expr: expr, name: name, args: args)
                
            case .ifStatement(let condition, let trueBody, let falseBody):
                return try ifStatement(condition: condition, true: trueBody, false: falseBody)
                
            case .loop(let body):
                return try loop(body: body)
            case .while(let cond, let body):
                return try vWhile(cond: cond, body: body)
            case .forange(let id, let first, let second, let body, let rev):
                return try forange(id: id, first: first, second: second, body: body, rev: rev)
                
            case .break:
                currentScope.unwind(to: .break)
                break
            case .continue:
                currentScope.unwind(to: .continue)
                break
                
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
                if currentScope.unwindStatus != nil {
                    break
                }
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
        
        func equalityOp(lhs: Node, op: Token, rhs: Node) throws -> Value {
            let lhs = try visit(node: lhs)
            let rhs = try visit(node: rhs)
            
            var result: Bool = false
            
            // If they point to the same value instance, they are the same
            if lhs === rhs { result = true }
            
            // Since previous is false, any of the two being null means they are not the same
            else if lhs === Value.null || rhs === Value.null { result = false }
            
            // If one is primitive, both are
            // SemAn guaranteed
            else if let lhs = lhs as? PrimitiveValue,
               let rhs = rhs as? PrimitiveValue {
                
                if lhs.isNumeric {
                    result = lhs.asDouble()! == rhs.asDouble()!
                } else if lhs.type == .boolType {
                    result = lhs.asBool()! == rhs.asBool()!
                } else if lhs.type == .textType {
                    result = lhs.asText()! == rhs.asText()!
                }
            }
            
            switch op.type {
            case .equals:
                break
            case .notEquals:
                result.toggle()
            default:
                fatalError("Internal: Invalid equality operation \(op) in the AST")
            }
            
            return BoolValue(value: result)
        }
        
        func relationalOp(lhs: Node, op: Token, rhs: Node) throws -> Value {
            let lhs = (try visit(node: lhs) as! PrimitiveValue).asDouble()!
            let rhs = (try visit(node: rhs) as! PrimitiveValue).asDouble()!
            
            var result: Bool = false
            
            switch op.type {
            case .lessThan:
                result = lhs < rhs
            case .lessOrEqualTo:
                result = lhs <= rhs
            case .greaterThan:
                result = lhs > rhs
            case .greaterOrEqualTo:
                result = lhs >= rhs
            default:
                fatalError("Internal: Invalid equality operation \(op) in the AST")
            }
            
            return BoolValue(value: result)
        }
        
        func assignment(to lhs: Node, val: Node) throws -> Value {
            let varSym = try currentScope.get(from: lhs) as! VarSymbol
            var newValue = try visit(node: val)
            
            if let _ = varSym.value {
                // If oldValue is copyable
                // Copy
                
                // Cast numeric value
                if varSym.type == .intType && newValue.type == .doubleType {
                    let internalValue = (newValue as! DoubleValue).asDouble()!
                    newValue = IntValue(value: Int(internalValue))
                } else if varSym.type == .doubleType && newValue.type == .intType {
                    let internalValue = (newValue as! IntValue).asDouble()!
                    newValue = DoubleValue(value: internalValue)
                }
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
            let symbol = currentScope[name.lexeme]
            
            switch symbol {
            case let varSymbol as VarSymbol:
                return varSymbol.value!
            case let nativeFuncSymbol as NativeFunctionSymbol:
                return nativeFuncSymbol.body!
            case let scriptedFuncSymbol as ScriptedFunctionSymbol:
                return scriptedFuncSymbol.value!
            default:
                break
            }
            
            throw OdoException.NameError(message: "Invalid identifier `\(name.lexeme!)`")
        }
        
        func varDeclaration(tp: Node, name: Token, initial: Node?) throws -> Value {
            var type = try currentScope.get(from: tp) as! TypeSymbol

            var initialValue: Value?
            if let initial = initial {
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
        
        func ifStatement(condition: Node, true trueBody: Node, false falseBody: Node?) throws -> Value {
            let condition = (try visit(node: condition) as! BoolValue).asBool()!
            
            if condition {
                try visit(node: trueBody)
            } else if let falseBody = falseBody {
                try visit(node: falseBody)
            }
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
        
        func getParamTypes(_ params: [Node]) throws -> [FunctionTypeSymbol.ArgumentDefinition] {
            var result: [FunctionTypeSymbol.ArgumentDefinition] = []
            for param in params {
                switch param {
                case .varDeclaration(let type, _, let initial):
                    let tp = try currentScope.get(from: type) as! TypeSymbol
                    let isOptional = initial != nil
                    result.append((tp, isOptional))
                default:
                    break
                }
            }
            
            return result
        }
        
        func functionBody(body: [Node]) throws -> Value {
            let temp = currentScope
            let bodyScope = SymbolTable("func-body-scope", parent: currentScope)
            bodyScope.unwindConditions = [.return]
            
            currentScope = bodyScope
            
            for st in body {
                try visit(node: st)
                if bodyScope.unwindStatus != nil {
                    bodyScope.stopUnwinding()
                    // Get the value
                    break
                }
            }
            
            currentScope = temp
            
            // Return the value
            return .null
        }
        
        func functionDeclaration(name: Token, args: [Node], returns: Node?, body: Node) throws -> Value {
            let returnType = try currentScope.get(from: returns) as? TypeSymbol
            
            let paramTypes = try getParamTypes(args)
            
            let typeName = FunctionTypeSymbol.constructFunctionName(ret: returnType, params: paramTypes)
            
            let typeOfFunction: ScriptedFunctionTypeSymbol
            
            if let inScope = globalTable[typeName] {
                typeOfFunction = inScope as! ScriptedFunctionTypeSymbol
            } else {
                typeOfFunction = ScriptedFunctionTypeSymbol(typeName, ret: returnType, args: paramTypes)
                globalTable.addSymbol(
                    typeOfFunction
                )
            }
            
            let funcValue = ScriptedFunctionValue(type: typeOfFunction, parameters: args, body: body, parentScope: currentScope)
            
            currentScope.addSymbol(ScriptedFunctionSymbol(name: name.lexeme, type: typeOfFunction, value: funcValue))
            
            return .null
        }
        
        func functionCall(expr: Node, name: Token?, args: [Node]) throws -> Value {
            let function = try visit(node: expr) as! FunctionValue
            
            switch function {
            case let native as NativeFunctionValue:
                let args = try args.map { node in try self.visit(node: node) }
                
                return try native.functionBody(args, self)
            case let scripted as ScriptedFunctionValue:
                return try callScriptedFunction(scripted, args: args)
            default:
                fatalError("Oh no")
            }
            
            return .null
        }
        
        func callScriptedFunction(_ fn: ScriptedFunctionValue, args: [Node]) throws -> Value {
            if callStack.count > Self.maxCallDepth {
                throw OdoException.RuntimeError(message: "Callback depth exceeded!")
            }
            
            let funcScope = SymbolTable("func-scope", parent: fn.parentScope)
            let calleeScope = currentScope
            
            var newDeclarations: [Node] = []
            var initialValues: [(Token, Value)] = []
            for (i, parameter) in fn.parameters.enumerated() {
                if args.count > i {
                    switch parameter {
                    case .varDeclaration(_, let name, _):
                        let newValue = try visit(node: args[i])
                        // TODO: Make sure copyable works
                        initialValues.append((name, newValue))
                        break
                    default:
                        break
                    }
                }
                
                newDeclarations.append(parameter)
            }
            
            currentScope = funcScope
            
            callStack.append(CallStackFrame())
            
            // Add the arguments to the scope
            for (i, decl) in newDeclarations.enumerated() {
                try visit(node: decl)
                
                if i < initialValues.count {
                    let varName = initialValues[i].0.lexeme!
                    let newVar = currentScope[varName]

                    // Please remember to update when new kinds
                    // of value-holding symbols are added.
                    // Thank you.
                    switch newVar {
                    case let variable as VarSymbol:
                        variable.value = initialValues[i].1
                    case let scriptedFunction as ScriptedFunctionSymbol:
                        scriptedFunction.value = (initialValues[i].1 as! ScriptedFunctionValue)
                    default:
                        break
                    }
                }
            }
            
            let result = try visit(node: fn.body)
            
            currentScope = calleeScope

            callStack.removeLast()
            
            return result
        }
        
        func loop(body: Node) throws -> Value {
            let loopScope = SymbolTable("loop:loop", parent: currentScope)
            loopScope.unwindConditions = [.break, .continue]
            currentScope = loopScope
            
            while true {
                try visit(node: body)
                if let unwinding = currentScope.unwindStatus {
                    currentScope.stopUnwinding()
                    if unwinding == .break {
                        break
                    } else {
                        continue
                    }
                }
            }
            
            currentScope = loopScope.parent!
            
            return .null
        }
        
        func vWhile(cond: Node, body: Node) throws -> Value {
            let whileScope = SymbolTable("while:loop", parent: currentScope)
            whileScope.unwindConditions = [.continue, .break]
            currentScope = whileScope
            let condResult = {
                (try self.visit(node: cond) as! BoolValue)
                    .value
            }


            while try condResult() {
                try visit(node: body)
                
                if let unwinding = currentScope.unwindStatus {
                    currentScope.stopUnwinding()
                    if unwinding == .break {
                        break
                    } else {
                        continue
                    }
                }
            }
            
            currentScope = whileScope.parent!
            
            return .null
        }
        
        func forange(id: Token?, first: Node, second: Node?, body: Node, rev: Bool) throws -> Value {
            let forangeScope = SymbolTable("forange:loop", parent: currentScope)
            forangeScope.unwindConditions = [.break, .continue]
            currentScope = forangeScope
            
            let first = (try visit(node: first) as! PrimitiveValue)
            
            let lowerBound: Int
            let upperBound: Int
            
            if let second = second {
                lowerBound = Int(first.asDouble()!)

                let second = (try visit(node: second) as! PrimitiveValue)
                upperBound = Int(second.asDouble()!)
            } else {
                lowerBound = 0
                upperBound = Int(first.asDouble()!)
            }
            
            let withIdentifier = id != nil
            
            let iterValue: IntValue!
            
            if withIdentifier {
                let _ = try varDeclaration(
                    tp: .variable(Token(type: .identifier, lexeme: "int")),
                    name: id!,
                    initial: .noOp
                )

                let iterId = currentScope[id!.lexeme, false]! as! VarSymbol
                iterValue = IntValue(value: 0)
                iterId.value = iterValue
                iterId.isInitialized = true
            } else {
                iterValue = nil
            }
            
            for i in lowerBound..<upperBound {
                if withIdentifier {
                    var actualValue = i
                    if rev { actualValue = lowerBound + upperBound - 1 - i }
                    
                    iterValue.value = actualValue
                }
                
                try visit(node: body)
                if let unwind = currentScope.unwindStatus {
                    currentScope.stopUnwinding()
                    if unwind == .continue {
                        continue
                    } else {
                        break
                    }
                }
            }
            
            currentScope = forangeScope.parent!
            
            return .null
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
