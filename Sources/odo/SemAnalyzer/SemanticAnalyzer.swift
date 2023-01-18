//
//  SemanticAnalyzer.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    struct LazyCheck {
        var parent: SymbolTable
        var body: (SymbolTable) throws ->Void
        var onError: (()->Void)?
    }
    
    class GenericSymbolMap<S: Symbol, T> {
        var checks: [Symbol: T] = [:]
        
        subscript(symbol: Symbol) -> T? {
            get {
                checks[symbol]
            }
            
            set {
                checks[symbol] = newValue
            }
        }
        
        func remove(_ sym: Symbol) {
            checks.removeValue(forKey: sym)
        }
    }
    
    struct FunctionDetails {
        init(expectedReturnType: Odo.TypeSymbol? = nil, returningAValue: Bool = false) {
            self.expectedReturnType = expectedReturnType
            self.returningAValue = returningAValue
        }
        
        var expectedReturnType: TypeSymbol?
        var returningAValue: Bool = false
        
        mutating func setReturning(to val: Bool) {
            returningAValue = val
        }
    }
    
    typealias SymbolMap<T> = GenericSymbolMap<Symbol, T>
    
    public class SemanticAnalyzer {
        let interpreter: Interpreter
        let globalScope: SymbolTable
        let replScope: SymbolTable
        
        var currentScope: SymbolTable
        
        typealias LazyScope = SymbolMap<LazyCheck>
        // Lazy Analysis
        var lazyScopeStack: [LazyScope] = []
        var currentLazyScope: LazyScope?
        
        // Symbol Meta Information
        let semanticContexts = SymbolMap<SymbolTable>()
        let functionContexts = GenericSymbolMap<FunctionTypeSymbol, [FunctionTypeSymbol.ArgumentDefinition]>()
        
        // Function Details stack
        var functionDetailsStack: [FunctionDetails] = []
        var currentFunctionDetails: FunctionDetails! {
            functionDetailsStack.last
        }
        
        init(inter: Interpreter) {
            self.interpreter = inter
            globalScope = SymbolTable("semanticGlobalTable", parent: inter.globalTable)
            replScope = SymbolTable("semanticRepl", parent: globalScope)
            currentScope = globalScope
            
            pushLazyScope()
        }
        
        func popLazyCheck(for sym: Symbol) -> LazyCheck? {
            //          A stack. I want to search from the tail
            if let indx = lazyScopeStack.lastIndex(where: { $0[sym] != nil }) {
                let check = lazyScopeStack[indx][sym]
                lazyScopeStack[indx].remove(sym)
                return check
            }
            return nil
        }
        
        func addLazyCheck(for sym: Symbol, check: LazyCheck) {
            sym.hasBeenChecked = false
            currentLazyScope?[sym] = check
        }
        
        func consumeLazy(symbol: Symbol) throws {
            if let lazyCheck = popLazyCheck(for: symbol) {
                symbol.hasBeenChecked = true
                do {
                    try lazyCheck.body(lazyCheck.parent)
                } catch let err as OdoException {
                    lazyCheck.onError?()
                    lazyCheck.parent.removeSymbol(symbol)
                    throw err
                }
            }
        }
        
        func pushLazyScope() {
            lazyScopeStack.append(LazyScope())
            currentLazyScope = lazyScopeStack.last
        }
        
        func popLazyScope() throws {
            if !lazyScopeStack.isEmpty, let scope = currentLazyScope {
                for (symbol, lazyCheck) in scope.checks {
                    if !symbol.hasBeenChecked {
                        symbol.hasBeenChecked = true
                        do {
                            try lazyCheck.body(lazyCheck.parent)
                        } catch let err as OdoException {
                            lazyCheck.onError?()
                            lazyCheck.parent.removeSymbol(symbol)
                            throw err
                        }
                    }
                }
            }
        }
        
        func pushFunctionDetails(ret: TypeSymbol? = nil) {
            functionDetailsStack.append(FunctionDetails(expectedReturnType: ret))
        }
        
        @discardableResult
        func popFunctionDetails() -> FunctionDetails? {
            functionDetailsStack.popLast()
        }
        
        @discardableResult
        func addSemanticContext(for sym: Symbol, scope: SymbolTable) -> SymbolTable {
            semanticContexts[sym] = scope
            
            sym.onDestruction = { [weak self] in
                self?.semanticContexts.remove(sym)
            }
            
            scope.owner = sym
            
            return scope
        }
        
        func addSemanticContext(for sym: Symbol, called name: String) -> SymbolTable {
            addSemanticContext(for: sym, scope: SymbolTable(name, parent: currentScope))
        }
        
        func addFunctionSemanticContext(
            for sym: FunctionTypeSymbol,
            name: String,
            params: [FunctionTypeSymbol.ArgumentDefinition]) -> SymbolTable {
            
            let funcTable = addSemanticContext(for: sym, called: name)
            
            functionContexts[sym] = params
            sym.onDestruction = nil

            return funcTable
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
            case .relationalOp(let lhs, let op, let rhs):
                return try relationalOp(lhs: lhs, op: op, rhs: rhs)
            case .ternaryOp(let condition, let trueCase, let falseCase):
                return try ternaryOp(condition: condition, true: trueCase, false: falseCase)
                
            case .unaryOp(_, let expr):
                let result = try visit(node: expr)
                guard result.tp?.isNumeric ?? false else {
                    throw OdoException.TypeError(message: "Invalid unary operator, can only be used in numeric values")
                }
                
                return result

            case .assignment(let lhs, let val):
                return try assignment(to: lhs, val: val)
            case .variable(let name):
                return try variable(name: name)
            case .varDeclaration(let tp, let name, let initial, let constant):
                return try varDeclaration(tp: tp, name: name, initial: initial, constant: constant)
                
            case .functionDeclaration(let name, let args, let returnType, let body):
                return try functionDeclaration(name: name, args: args, returns: returnType, body: body)
            case .functionBody(let statements):
                return try functionBody(body: statements)
            case .functionCall(let expr, let name, let args):
                return try functionCall(expr: expr, name: name, args: args)
            case .returnStatement(let expr):
                return try returnStatement(expr: expr)
                
            case .ifStatement(let condition, let trueBody, let falseBody):
                return try ifStatement(cond: condition, true: trueBody, false: falseBody)
                
            case .loop(let body):
                return try loop(body: body)
            case .while(let cond, let body):
                return try vWhile(cond: cond, body: body)
            case .forange(let id, let first, let second, let body, let rev):
                return try forange(id: id, first: first, second: second, body: body, rev: rev)
                
            case .break:
                if !currentScope.canUnwind(to: .break) {
                    throw OdoException.SemanticError(message: "Invalid use of `break` statement outside of loop.")
                }
                // Can break?
                return .nothing
            case .continue:
                if !currentScope.canUnwind(to: .continue) {
                    throw OdoException.SemanticError(message: "Invalid use of `continue` statement outside of loop.")
                }
                // Can break?
                return .nothing
                
            case .staticAccess(_, _):
                if let sym = try getSymbol(from: node) {
                    return NodeResult(tp: sym.type)
                }
                throw OdoException.SemanticError(message: "Invalid static access")
                
            case .module(let name, let body):
                return try module(name: name, body: body)
                
            case .enum(let name, let cases):
                return try enumDeclaration(name: name, cases: cases)
                
            case .functionType(_, _):
                throw OdoException.SemanticError(message: "Invalid use of function type.")
            
            case .noOp:
                return .nothing
            }
        }
        
        func getSymbol(from node: Node) throws -> Symbol? {
            var result: Symbol? = nil

            switch node {
            case .variable(let name):
                if let found = currentScope[name] {
                    result = found
                }
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
                    result = globalScope.addSymbol(functionType)
                }
            case .staticAccess(let expr, let name):
                guard let leftHand = try getSymbol(from: expr) else {
                    throw OdoException.ValueError(message: "Invalid static access on unknown symbol")
                }
                
                switch leftHand {
                case let asModule as ModuleSymbol:
                    let moduleContext = semanticContexts[asModule]
                    result = moduleContext![name, false]
                case let asEnum as EnumSymbol:
                    let enumContext = semanticContexts[asEnum]
                    result = enumContext?[name]
                default:
                    throw OdoException.NameError(message: "Cannot acces static symbol in this node")
                }
                
            default:
                break
            }

            if let sym = result {
                if !sym.hasBeenChecked { try consumeLazy(symbol: sym) }
                return sym
            }
            
            return nil
        }
        
        func block(body: [Node]) throws -> NodeResult {
            let tempScope = currentScope
            currentScope = SymbolTable("block_scope", parent: currentScope)
            pushLazyScope()
            
            for statement in body {
                try visit(node: statement)
            }
            
            try popLazyScope()
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
        
        func relationalOp(lhs: Node, op: Token, rhs: Node) throws -> NodeResult {
            switch op.type {
            case .lessThan, .lessOrEqualTo, .greaterThan, .greaterOrEqualTo:
                break
            default:
                throw OdoException.SemanticError(message: "Internal. Invalid operator \(op) for relational expression")
            }
            
            let lhs = try visit(node: lhs)
            guard lhs.tp != nil else {
                throw OdoException.ValueError(message: "Left operand in relational operator \(op) must return a value.")
            }
            let rhs = try visit(node: rhs)
            guard rhs.tp != nil else {
                throw OdoException.ValueError(message: "Right operand in relational operator \(op) must return a value.")
            }
            
            guard lhs.tp!.isNumeric && rhs.tp!.isNumeric else {
                throw OdoException.TypeError(
                    message: "Invalid relational operation `\(op)`. Operands must be of numeric types.")
            }
            
            return NodeResult(tp: .boolType)
        }
        
        func assignment(to lhs: Node, val: Node) throws -> NodeResult {
            if let sym = try getSymbol(from: lhs) {
                guard let _ = sym.type, !sym.isType else {
                    // Error! Invalid assignment
                    throw OdoException.SemanticError(message: "Invalid assignment to symbol `\(sym.qualifiedName)`.")
                }
                
                let newValue = try visit(node: val)
                
                guard let newType = newValue.tp else {
                    throw OdoException.SemanticError(message: "Invalid assignment to symbol `\(sym.qualifiedName)`. Operation doesn't provide a value.")
                }
                
                if !sym.isInitialized {
                    if sym.type == .anyType {
                        sym.type = newType
                    }
                    
                    sym.isInitialized = true
                } else {
                    if sym.isConstant {
                        throw OdoException.SemanticError(message: "Invalid assignment to constant `\(sym.qualifiedName)`.")
                    }
                }
                
                if !counts(type: newType, as: sym.type!) {
                    throw OdoException.TypeError(
                        message: "Invalid assignment, variable `\(sym.qualifiedName)` expected value of type `\(sym.type!.qualifiedName)` but recieved `\(newValue.tp?.qualifiedName ?? "no value")`")
                }
                
                // TODO: Set constantness and side effects for symbol
            } else {
                // Error!
                throw OdoException.NameError(message: "Assignment to unknown variable.")
            }
            
            return .nothing
        }
        
        func variable(name: String) throws -> NodeResult {
            guard let sym = currentScope[name] else {
                throw OdoException.NameError(message: "Variable called `\(name)` not defined.")
            }
            
            if !sym.hasBeenChecked {
                try consumeLazy(symbol: sym)
            }
            
            if sym.isInitialized {
                // TODO: Constantness info
                return NodeResult(tp: sym.type)
            }
            
            throw OdoException.ValueError(message: "Using variable `\(sym.qualifiedName)` when is hasn't been initialized.")
        }
        
        func varDeclaration(tp: Node, name: String, initial: Node?, constant: Bool) throws -> NodeResult {
            if let _ = currentScope[name, false] {
                throw OdoException.NameError(message: "Variable called `\(name)` already exists.")
            }
            
            guard let type = try getSymbol(from: tp) else {
                throw OdoException.NameError(message: "Unknown type `\(tp)`")
            }
            
            guard let type = type as? TypeSymbol else {
                throw OdoException.TypeError(message: "Symbol `\(type.qualifiedName)` is not a valid type.")
            }
            
            if !type.hasBeenChecked {
                try consumeLazy(symbol: type)
            }
            
            let newVar = VarSymbol(name: name, type: type, isConstant: constant)

            if let initial = initial {
                let newValue = try visit(node: initial)
                
                guard let newType = newValue.tp else {
                    throw OdoException.ValueError(message: "Initial expression for declaration of `\(newVar.qualifiedName)` does not provide a value.")
                }
                
                if !newType.hasBeenChecked {
                    try consumeLazy(symbol: newType)
                }
                
                guard counts(type: newType, as: type) else {
                    throw OdoException.TypeError(message: "Invalid declaration, variable `\(newVar.qualifiedName)` expected value of type `\(type.qualifiedName)` but recieved `\(newType.qualifiedName)`")
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
        
        func getParameterTypes(_ params: [Node]) throws -> [FunctionTypeSymbol.ArgumentDefinition] {
            var result: [FunctionTypeSymbol.ArgumentDefinition] = []
            var hasSeenOptional = false
            for par in params {
                var isOptional: Bool
                let tp: TypeSymbol
                
                switch par {
                case .varDeclaration(let type, _, let initial, _):
                    guard let varType = try getSymbol(from: type) as? TypeSymbol else {
                        throw OdoException.TypeError(message: "Type is invalid for parameter declaration")
                    }
                    
                    tp = varType
                    isOptional = initial != nil
                default:
                    throw OdoException.SyntaxError(message: "Invalid statement in function declaration. Expected parameter declaration")
                }
                
                if isOptional {
                    if hasSeenOptional {
                        throw OdoException.SemanticError(message: "Cannot define non optional parameter after an optional")
                    }

                    hasSeenOptional = true
                }
                
                result.append((tp, isOptional))
            }
            return result
        }
        
        func functionBody(body: [Node]) throws -> NodeResult{
            let temp = currentScope
            let bodyScope = SymbolTable("func-body-scope", parent: currentScope)
            bodyScope.unwindConditions = [.return]
            
            currentScope = bodyScope
            
            for st in body {
                try visit(node: st)
            }

            currentScope = temp
            return .nothing
        }
        
        func functionDeclaration(name: String, args: [Node], returns: Node?, body: Node) throws -> NodeResult {
            if currentScope[name, false] != nil {
                throw OdoException.NameError(message: "Function called `\(name)` already exists in this scope")
            }
            
            let returnType: TypeSymbol?
            if let returns = returns {
                guard let typeSymbol = try getSymbol(from: returns) as? TypeSymbol else {
                    throw OdoException.TypeError(message: "Type `\(returns)` is not a valid type.")
                }

                returnType = typeSymbol
            } else {
                returnType = nil
            }
            
            let paramTypes = try getParameterTypes(args)
            
            let typeName = FunctionTypeSymbol.constructFunctionName(ret: returnType, params: paramTypes)
            
            let functionType: ScriptedFunctionTypeSymbol
            
            let funcScope: SymbolTable
            
            if let inScope = currentScope[typeName] {
                // Semantic context handling
                functionType = inScope as! ScriptedFunctionTypeSymbol
                
                if let existingContext = semanticContexts[functionType] {
                    funcScope = existingContext.copy()
                } else {
                    funcScope = addFunctionSemanticContext(for: functionType, name: typeName, params: paramTypes).copy()
                }
            } else {
                functionType = ScriptedFunctionTypeSymbol(typeName, ret: returnType, args: paramTypes)
                
                globalScope.addSymbol(functionType)
                funcScope = addFunctionSemanticContext(for: functionType, name: typeName, params: paramTypes).copy()
            }
            
            funcScope.parent = currentScope
            
            let functionSymbol = currentScope.addSymbol(ScriptedFunctionSymbol(name: name, type: functionType))
            functionSymbol?.isInitialized = true
            
            let temp = currentScope
            currentScope = funcScope
            
            // TODO: Handle parameters
            for par in args {
                try visit(node: par)
                let name: String
                switch par {
                case .varDeclaration(_, let varName, _, _):
                    name = varName
                default:
                    name = ""
                }
                
                currentScope[name]?.isInitialized = true
            }
            
            addLazyCheck(
                for: functionSymbol!,
                check: LazyCheck(parent: temp) { _ in
                    let temp = self.currentScope
                    self.currentScope = funcScope
                    self.pushFunctionDetails(ret: functionType.returnType)
                    try self.visit(node: body)
                    
                    if self.currentFunctionDetails.expectedReturnType != nil {
                        guard self.currentFunctionDetails.returningAValue else {
                            throw OdoException.SemanticError(
                                message: "Function ends without returning a value."
                            )
                        }
                    }
                    
                    self.popFunctionDetails()
                    self.currentScope = temp
                }
            )
            
            currentScope = temp
            
            return .nothing
        }
        
        func functionCall(expr: Node, name: String?, args: [Node]) throws -> NodeResult {
            let function = try getSymbol(from: expr)
            
            guard let _ = function?.type as? FunctionTypeSymbol else {
                throw OdoException.TypeError(message: "Invalid function call. Value of type `\(function?.qualifiedName ?? "")` is not a function.")
            }

            if let functionType = function?.type as? ScriptedFunctionTypeSymbol {
                let parametersInTemplate = functionContexts[functionType]!
                
                if args.count > parametersInTemplate.count {
                    throw OdoException.SemanticError(message: "Function `\(function?.qualifiedName ?? "")` takes a maximum of \(parametersInTemplate.count) arguments, but was called with \(args.count).")
                }
                
                for (i, paramDef) in parametersInTemplate.enumerated() {
                    let (param, isOptional) = paramDef
                    
                    if args.count > i {
                        let argument = args[i]
                        let argValue = try visit(node: argument)
                        // Handle Empty Lists
                        
                        guard let argType = argValue.tp else {
                            throw OdoException.ValueError(message: "Function call argument \(i) does not provide a value")
                        }
                        
                        if !counts(type: argType, as: param) {
                            throw OdoException.TypeError(message: "Invalid type for argument \(i) of function. Expected type `\(param.qualifiedName)` but received `\(argType.qualifiedName)`.")
                        }
                    } else if !isOptional {
                        throw OdoException.ValueError(message: "No value for function call argument \(i)")
                    }
                }
                return NodeResult(tp: functionType.returnType)
            } else if let native = function as? NativeFunctionSymbol {
                switch native.argCount {
                case .nothing:
                    guard args.isEmpty else {
                        throw OdoException.ValueError(
                            message: "Function `\(native.qualifiedName)` takes no arguments."
                        )
                    }
                case .whatever:
                    break
                case .some(let x):
                    guard args.count == x else {
                        throw OdoException.ValueError(
                            message: "Function `\(native.qualifiedName)` takes `\(x)` arguments."
                        )
                    }
                case .someOrLess(let x):
                    guard args.count <= x else {
                        throw OdoException.ValueError(
                            message: "Function `\(native.qualifiedName)` takes `\(x)` arguments or less."
                        )
                    }
                }
                
                for arg in args {
                    try visit(node: arg)
                }
                
                let result = try native.semanticTest(args, self)
                
                return NodeResult(tp: result)
            }
            
            return .nothing
        }
        
        func returnStatement(expr: Node?) throws -> NodeResult {
            if !currentScope.canUnwind(to: .return) {
                throw OdoException.SemanticError(message: "Use of return statement outside of a function")
            }
            if let expr = expr {
                guard let expected = currentFunctionDetails.expectedReturnType else {
                    throw OdoException.ValueError(message: "Invalid return in void function.")
                }
                let value = try visit(node: expr)
                if let returningType = value.tp {
                    if !counts(type: returningType, as: expected) {
                        throw OdoException.TypeError(
                            message: "Returning value with invalid type. Expected `\(currentFunctionDetails.expectedReturnType?.qualifiedName ?? "")` but recieved `\(returningType.qualifiedName)`"
                        )
                    }
                } else {
                    throw OdoException.ValueError(message: "Expression in return statement doesn't provide a value")
                }
            } else if let expected = currentFunctionDetails.expectedReturnType {
                throw OdoException.ValueError(message: "Expected value of type `\(expected.qualifiedName)` in return.")
            }
            
            let lastIndx = functionDetailsStack.count-1
            functionDetailsStack[lastIndx].setReturning(to: true)
            currentScope.unwind(to: .return)
            return .nothing
        }
        
        func ifStatement(cond condition: Node, true trueBody: Node, false falseBody: Node?) throws -> NodeResult {
            let condition = try visit(node: condition)
            
            guard condition.tp == .boolType else {
                throw OdoException.TypeError(message: "Condition of if statement must be boolean")
            }
            
            try visit(node: trueBody)
            
            if let falseBody = falseBody {
                try visit(node: falseBody)
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
            let loopScope = SymbolTable("loop:loop", parent: currentScope)
            loopScope.unwindConditions = [.break, .continue]
            currentScope = loopScope
            
            try visit(node: body)

            currentScope = loopScope.parent!
            return .nothing
        }
        
        func vWhile(cond: Node, body: Node) throws -> NodeResult {
            let whileScope = SymbolTable("while:loop", parent: currentScope)
            whileScope.unwindConditions = [.break, .continue]
            currentScope = whileScope
            let cond = try visit(node: cond)
            
            if cond.tp != .boolType {
                throw OdoException.TypeError(message: "Condition expression of while statement must be boolean.")
            }
            
            try visit(node: body)
            
            currentScope = whileScope.parent!
            
            return .nothing
        }
        
        func forange(id: String?, first: Node, second: Node?, body: Node, rev: Bool) throws -> NodeResult {
            let forangeScope = SymbolTable("forange:loop", parent: currentScope)
            forangeScope.unwindConditions = [.break, .continue]
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
                    tp: .variable("int"),
                    name: usingId,
                    initial: nil,
                    constant: true
                )

                currentScope[usingId, false]!.isInitialized = true
            }
            
            try visit(node: body)
            
            currentScope = forangeScope.parent!
            
            return .nothing
        }
        
        func module(name: String, body: [Node]) throws -> NodeResult {
            if let moduleInTable = currentScope.addSymbol(ModuleSymbol(name: name)) {
                let moduleContext = addSemanticContext(for: moduleInTable, called: "module_\(moduleInTable.qualifiedName)_scope")
                moduleInTable.isInitialized = true
                
                addLazyCheck(
                    for: moduleInTable,
                    check: LazyCheck(parent: currentScope) { _ in
                        let temp = self.currentScope
                        self.currentScope = moduleContext
                        self.pushLazyScope()
                        
                        for statement in body {
                            try self.visit(node: statement)
                        }
                        
                        try self.popLazyScope()
                        
                        try moduleContext.forEach { name, sym in
                            if !sym.isInitialized {
                                throw OdoException.SemanticError(message: "Symbol `\(name)` in module was not initialized")
                            }
                        }
                        
                        self.currentScope = temp
                    }
                )
            }
            return .nothing
        }
        
        func enumDeclaration(name: String, cases: [String]) throws -> NodeResult {
            guard currentScope[name, false] == nil else {
                throw OdoException.NameError(message: "Symbol called `\(name)` already exists in this scope.")
            }
            
            let enumType = EnumSymbol(name: name)
            let enumScope = SymbolTable("enum_\(name)_scope")

            for caseName in cases {
                enumScope.addSymbol(EnumCaseSymbol(name: caseName, type: enumType))
            }
            
            addSemanticContext(for: enumType, scope: enumScope)
            
            currentScope.addSymbol(enumType)
            
            return .nothing
        }
        
        public func validate(arg: Node, type: TypeSymbol) throws {
            let argument = try visit(node: arg)

            guard let argType = argument.tp, counts(type: argType, as: type) else {
                throw OdoException.TypeError(message: "Function takes an argument of type `\(type.qualifiedName)`.")
            }
        }
        
        func counts(type left: TypeSymbol, as right: TypeSymbol) -> Bool {
            if right == .anyType { return true }
//            if left is null and right a class type { return true }
            
            if left.isNumeric && right.isNumeric { return true }
            
            print("Comparing: \(left.qualifiedName) to \(right.qualifiedName)")
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
