//
//  Interpreter.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//
import Foundation

extension Odo {
    public class Interpreter {
        let parser = Parser()
        lazy var semAn: SemanticAnalyzer = SemanticAnalyzer(inter: self)
        
        let globalTable: SymbolTable
        let replScope: SymbolTable
        
        var currentScope: SymbolTable
        
        static let maxCallDepth: UInt = 600
        var callStack: [CallStackFrame] = []
        
        var lazyEvaluations = SymbolMap<LazyEvaluation>()
        
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
        
        /// Create a function accessible from runtime Odo code
        /// that executes native swift. You should make sure that yout validation
        /// is as thourough as possible.
        /// - Parameters:
        ///   - name: The name of the symbol from which this function can be accessed
        ///   - body: The closure that is executed. It takes it's arguments as [Value]
        ///   - validation: The semantic validation of arguments and return type, recieves the list of Node and the Semantic analyzer.
        ///   Preferably gives static return type for all calls.
        public func addFunction(
            _ name: String,
            takes args: NativeFunctionSymbol.ArgType = .nothing,
            body: @escaping ([Value], Interpreter) throws -> Value,
            validation: (([Node], SemanticAnalyzer) throws -> TypeSymbol?)? = nil) {
                
                let functionSymbol = NativeFunctionSymbol(name: name, takes: args, validation: validation)
                globalTable.addSymbol(functionSymbol)
                
                let functionValue = NativeFunctionValue(body: body)
                functionSymbol.body = functionValue
            }
        
        public func addVoidFunction(
            _ name: String,
            takes args: NativeFunctionSymbol.ArgType = .nothing,
            body: @escaping ([Value], Interpreter) throws -> Void,
            validation: (([Node], SemanticAnalyzer) throws -> Void)? = nil) {
                addFunction(
                    name,
                    takes: args,
                    body: {val, inter -> Value in
                        try body(val, inter)
                        return .null
                    },
                    validation: validation == nil
                    ? nil
                    : { try validation!($0, $1); return nil }
                )
            }
        
        // TODO: Centralize all these functions,
        //       so I don't need to repeat so much code in native module.
        public func addFunction(
            _ name: String,
            takes: [NativeFunctionSymbol.ArgumentDescription] = [],
            returns: TypeSymbol?,
            body: @escaping ([Value], Interpreter) throws -> Value
        ) {
            let args = takes.map { $0.get() }
            let functionType = ScriptedFunctionTypeSymbol(ret: returns, args: args)
            let functionSymbol = NativeFunctionSymbol(name: name, validation: nil)
            functionSymbol.type = functionType
            
            globalTable.addSymbol(functionSymbol)
            let _ = semAn.addFunctionSemanticContext(for: functionType, name: functionType.name, params: args)
            
            let functionValue = NativeFunctionValue(body: body)
            functionValue.optionalArgs = takes.map { $0.getValue() }
            functionSymbol.body = functionValue
        }
        
        public func addVoidFunction(
            _ name: String,
            takes: [NativeFunctionSymbol.ArgumentDescription] = [],
            body: @escaping ([Value], Interpreter) throws -> Void
        ) {
            addFunction(name, takes: takes, returns: nil){
                try body($0, $1)
                return .null
            }
        }
        
        public func addVoidFunction(
            _ name: String,
            body: @escaping(() throws -> Void)
        ) {
            addVoidFunction(name, body: { _, _ in try body() })
        }
        
        public func addModule(_ name: String) -> NativeModule {
            let moduleValue = NativeModule(name: name, inter: self)
            let moduleSymbol = ModuleSymbol(name: name, value: moduleValue)
            
            globalTable.addSymbol(
                moduleSymbol
            )
            
            moduleSymbol.isInitialized = true
            
            semAn.addSemanticContext(for: moduleSymbol, scope: moduleValue.scope)
            
            return moduleValue
        }
        
        @discardableResult
        func visit(node: Node) throws -> Value {
            switch node {
            case .block(let body):
                return try block(body: body)
            case .double(let value):
                return DoubleValue(value: Double(value)!)
            case .int(let value):
                return IntValue(value: Int(value)!)
            case .text(let value):
                return TextValue(value: value)
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
                
            case .unaryOp(let op, let expr):
                let mult = op.type == .plus ? 1 : -1
                let result = try visit(node: expr) as! PrimitiveValue
                let value = result.asDouble()!
                if result.isInt { return IntValue(value: mult * Int(value)) }
                else { return DoubleValue(value: Double(mult) * value) }
                
            case .assignment(let lhs, let val):
                return try assignment(to: lhs, val: val)
            case .variable(let name):
                return try variable(name: name)
            case .varDeclaration(let tp, let name, let initial, let constant):
                return try varDeclaration(tp: tp, name: name, initial: initial, constant: constant)
                
            case .functionBody(let args):
                return try functionBody(body: args)
            case .functionDeclaration(let name, let args, let ret, let body):
                return try functionDeclaration(name: name, args: args, returns: ret, body: body)
            case .functionExpression(let args, let ret, let body):
                return try functionExpression(args: args, returns: ret, body: body)
            case .functionCall(let expr, let name, let args):
                return try functionCall(expr: expr, name: name, args: args)
            case .returnStatement(let expr):
                return try returnStatement(expr: expr)
                
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
                
            case .staticAccess(let node, let name):
                return try staticAccess(node: node, name: name)
            case .module(let name, let body):
                return try module(name: name, body: body)
                
            case .enum(let name, let cases):
                return try enumDeclaration(name: name, cases: cases)
                
            case .functionType(_, _):
                throw OdoException.SemanticError(message: "Invalid use of function type.")
                
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
            let leftVisited = try visit(node: lhs)
            let rightVisited = try visit(node: rhs)
            
            if leftVisited.type == .textType || rightVisited.type == .textType {
                return arithmeticWithTexts(lhs: leftVisited, op: op, rhs: rightVisited)
            }
            
            let lhs = leftVisited as! PrimitiveValue
            let rhs = rightVisited as! PrimitiveValue
            
            var isDouble = lhs.isDouble || rhs.isDouble
            
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
            let varSym = try getSymbol(from: lhs) as! VarSymbol
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
        
        func variable(name: String) throws -> Value {
            let symbol = currentScope[name]
            
            switch symbol {
            case let varSymbol as VarSymbol:
                return varSymbol.value!
            case let moduleSymbol as ModuleSymbol:
                return moduleSymbol.value!
            case let nativeFuncSymbol as NativeFunctionSymbol:
                return nativeFuncSymbol.body!
            case let scriptedFuncSymbol as ScriptedFunctionSymbol:
                return scriptedFuncSymbol.value!
            case let enumSymbol as EnumSymbol:
                return enumSymbol.value!
            case let enumCase as EnumCaseSymbol:
                return enumCase.value!
            default:
                break
            }
            
            throw OdoException.NameError(message: "Invalid identifier `\(name)`")
        }
        
        func varDeclaration(tp: Node, name: String, initial: Node?, constant: Bool) throws -> Value {
            var type = try getSymbol(from: tp) as! TypeSymbol
            
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
            
            let newVar: VarSymbol = VarSymbol(name: name, type: type, value: initialValue, isConstant: constant)
            
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
                case .varDeclaration(let type, _, let initial, _):
                    let tp = try getSymbol(from: type) as! TypeSymbol
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
            
            var returnValue: Value = .null
            
            for st in body {
                try visit(node: st)
                if bodyScope.unwindStatus != nil {
                    bodyScope.stopUnwinding()
                    returnValue = callStack.last?.returnValue ?? .null
                    break
                }
            }
            
            currentScope = temp
            
            // Return the value
            return returnValue
        }
        
        func functionDeclaration(name: String, args: [Node], returns: Node?, body: Node) throws -> Value {
            let returnType = try getSymbol(from: returns) as? TypeSymbol
            
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
            
            currentScope.addSymbol(ScriptedFunctionSymbol(name: name, type: typeOfFunction, value: funcValue))
            
            return .null
        }
        
        func functionExpression(args: [Node], returns: Node?, body: Node) throws -> Value {
            let returnType = try getSymbol(from: returns) as? TypeSymbol
            
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
            
            return funcValue
        }
        
        func functionCall(expr: Node, name: String?, args: [Node]) throws -> Value {
            let functionSymbol = try getSymbol(from: expr)
            
            switch functionSymbol {
            case let nativeSym as NativeFunctionSymbol:
                let args = try args.map { node in try self.visit(node: node) }
                
                let native = nativeSym.body!
                var actualArgs: [Value] = args
                
                if let optionals = native.optionalArgs {
                    actualArgs = []
                    for (i, val) in optionals.enumerated() {
                        if i < args.count {
                            actualArgs.append(args[i])
                        } else {
                            actualArgs.append(val!)
                        }
                    }
                }
                
                return try native.functionBody(actualArgs, self)
            case let scripted as ScriptedFunctionSymbol:
                return try callScriptedFunction(scripted.value!, args: args)
            default:
                let functionType = functionSymbol?.type as? ScriptedFunctionTypeSymbol
                if functionType != nil,
                   let functionSymbol = functionSymbol as? VarSymbol,
                   let functionValue = functionSymbol.value as? ScriptedFunctionValue
                {
                    return try callScriptedFunction(functionValue, args: args)
                }
                
                fatalError("Oh no")
            }
        }
        
        func returnStatement(expr: Node?) throws -> Value{
            if let expr = expr {
                let val = try visit(node: expr)
                
                let lastIndex = callStack.count - 1
                callStack[lastIndex].returnValue = val
            }
            
            currentScope.unwind(to: .return)
            return .null
        }
        
        func callScriptedFunction(_ fn: ScriptedFunctionValue, args: [Node]) throws -> Value {
            if callStack.count > Self.maxCallDepth {
                throw OdoException.RuntimeError(message: "Callback depth exceeded!")
            }
            
            let funcScope = SymbolTable("func-scope", parent: fn.parentScope)
            let calleeScope = currentScope
            
            var newDeclarations: [Node] = []
            var initialValues: [(String, Value)] = []
            for (i, parameter) in fn.parameters.enumerated() {
                if args.count > i {
                    switch parameter {
                    case .varDeclaration(_, let name, _, _):
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
                    let varName = initialValues[i].0
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
                    if unwinding == .continue {
                        continue
                    } else {
                        break
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
                    if unwinding == .continue {
                        continue
                    } else {
                        break
                    }
                }
            }
            
            currentScope = whileScope.parent!
            
            return .null
        }
        
        func forange(id: String?, first: Node, second: Node?, body: Node, rev: Bool) throws -> Value {
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
                    tp: .variable("int"),
                    name: id!,
                    initial: .noOp,
                    constant: true
                )
                
                let iterId = currentScope[id!, false]! as! VarSymbol
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
        
        func staticAccess(node: Node, name: String) throws -> Value {
            let symbol = try getSymbol(from: node)
            if let moduleSym = symbol as? ModuleSymbol {
                let moduleValue = moduleSym.value!
                
                let sym = moduleValue.scope[name]!
                switch sym {
                case let variable as VarSymbol:
                    return variable.value!
                case let scriptedFunction as ScriptedFunctionSymbol:
                    return scriptedFunction.value!
                case let nativeFunction as NativeFunctionSymbol:
                    return nativeFunction.body!
                case let module as ModuleSymbol:
                    return module.value!
                default:
                    return .null
                }
            } else if let enumSym = symbol as? EnumSymbol {
                let enumValue = enumSym.value!
                
                return (enumValue.scope[name] as! EnumCaseSymbol).value!
            } else {
                return .null
            }
        }
        
        func module(name: String, body: [Node]) throws -> Value {
            let moduleName = "module_\(name)_scope"
            let moduleScope = SymbolTable(moduleName, parent: currentScope)
            
            let moduleValue = ModuleValue(scope: moduleScope)
            
            if let inTable = currentScope.addSymbol(ModuleSymbol(name: name, value: moduleValue)) {
                moduleScope.owner = inTable // The value is the actual owner,
                                            // but a value can't qualify a name.
                lazyEvaluations[inTable] = LazyEvaluation(scope: moduleScope, nodes: body)
            }
            
            return .null
        }
        
        func enumDeclaration(name: String, cases: [String]) throws -> Value {
            let enumSymbol = EnumSymbol(name: name)
            let enumScope = SymbolTable("enum_\(name)_scope")
            
            let enumValue = EnumValue(scope: enumScope)
            enumSymbol.value = enumValue
            
            for caseName in cases {
                let caseValue = EnumCaseValue(name: caseName, type: enumSymbol)
                let caseSymbol = EnumCaseSymbol(name: caseName, type: enumSymbol, value: caseValue)
                
                enumScope.addSymbol(caseSymbol)
            }
            
            currentScope.addSymbol(enumSymbol)
            
            return .null
        }
        
        // Scope management
        func evaluateIfLazily(symbol: Symbol?) throws {
            guard let symbol else { return }
            
            guard let lazyEvaluation = lazyEvaluations[symbol] else { return }
            
            lazyEvaluations.remove(symbol)
            
            let tempScope = currentScope
            currentScope = lazyEvaluation.scope
            
            for node in lazyEvaluation.nodes {
                try visit(node: node)
            }
            
            currentScope = tempScope
        }
        
        func getSymbol(from node: Node?, andParents: Bool = true) throws -> Symbol? {
            guard let node = node else { return nil }
            
            let result: Symbol?
            
            switch node {
            case .variable(let name):
                result = currentScope[name]
            case .functionType(let args, let ret):
                let actualArgs = try args.map { argDef -> (TypeSymbol, Bool) in
                    let (type, isOptional) = argDef
                    guard let actualType = try getSymbol(from: type) as? TypeSymbol else {
                        throw OdoException.NameError(message: "Invalid type in function type arguments.")
                    }
                    
                    return (actualType, isOptional)
                }
                
                let returns: TypeSymbol?
                if let ret = ret {
                    guard let found = try getSymbol(from: ret) as? TypeSymbol else {
                        throw OdoException.NameError(message: "Invalid return type in function type arguments.")
                    }
                    
                    returns = found
                } else {
                    returns = nil
                }
                
                let funcName = FunctionTypeSymbol.constructFunctionName(ret: returns, params: actualArgs)
                if let functionType = currentScope[funcName] as? ScriptedFunctionTypeSymbol {
                    result = functionType
                } else {
                    let functionType = ScriptedFunctionTypeSymbol(funcName, ret: returns, args: actualArgs)
                    result = currentScope.topScope.addSymbol(functionType)
                }
            case .staticAccess(let expr, let name):
                guard let leftHand = try getSymbol(from: expr) else {
                    throw OdoException.ValueError(message: "Invalid static access on unknown symbol")
                }
                
                switch leftHand {
                case let asModule as ModuleSymbol:
                    let moduleContext = asModule.value
                    result = moduleContext?.scope[name]
                case let asEnum as EnumSymbol:
                    let enumContext = asEnum.value
                    result = enumContext?.scope[name]
                default:
                    // Innaccessible, based on semantic analysis
                    result = nil
                }
                
            default:
                result = nil
            }
            
            try evaluateIfLazily(symbol: result)
            
            return result
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

extension Odo.Interpreter {
    struct LazyEvaluation {
        weak var scope: Odo.SymbolTable!
        var nodes: [Odo.Node]
        init(scope: Odo.SymbolTable, nodes: [Odo.Node]) {
            self.scope = scope
            self.nodes = nodes
        }
    }
}
