//
//  Symbol.swift
//  odo
//
//  Created by Luis Gonzalez on 30/5/21.
//

import Foundation

extension Odo {
    public class Symbol: Equatable, Hashable {
        let id = UUID()
        public static func == (lhs: Odo.Symbol, rhs: Odo.Symbol) -> Bool {
            return lhs.id == rhs.id
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        var type: TypeSymbol?
        
        var name: String
        
        var isType: Bool { false }
        
        // Semantic Information
        var isInitialized = true
        var hasBeenChecked = true
        
        var onDestruction: (()->Void)?
        
        init(name: String, type: TypeSymbol) {
            self.name = name
            self.type = type
        }
        
        fileprivate init(name: String) {
            self.type = nil
            self.name = name
        }
        
        deinit {
            onDestruction?()
        }
        
        func toString() -> String {
            return "Type(\(name))"
        }
        
        // Builtin types
        public static let anyType      = PrimitiveTypeSymbol(name: "any")
        public static let nullType     = PrimitiveTypeSymbol(name: "$nullType", type: .anyType)
        public static let boolType     = PrimitiveTypeSymbol(name: "bool", type: .anyType)
        public static let textType     = PrimitiveTypeSymbol(name: "text", type: .anyType)
        
        public static let intType: PrimitiveTypeSymbol     = {
            let val = PrimitiveTypeSymbol(name: "int", type: .anyType)
            val.isNumeric = true
            return val
        }()

        public static let doubleType: PrimitiveTypeSymbol  = {
            let val = PrimitiveTypeSymbol(name: "double", type: .anyType)
            val.isNumeric = true
            return val
        }()
    }

    public class TypeSymbol: Symbol {
        override var isType: Bool { true }
        var isPrimitive: Bool { false }
        
        fileprivate(set) var isNumeric = false
        
        override init(name: String, type: TypeSymbol?) {
            super.init(name: name)
        }
    }
    
    public class PrimitiveTypeSymbol: TypeSymbol {
        override var isPrimitive: Bool { true }
        override init(name: String, type tp: TypeSymbol? = nil) {
            super.init(name: name, type: tp)
        }
    }
    
    class FunctionTypeSymbol: TypeSymbol {
        typealias ArgumentDefinition = (TypeSymbol, Bool)
        class func constructFunctionName(ret: TypeSymbol?, params: [(TypeSymbol, Bool)]) -> String {
            var result = "<"
            
            for (i, paramDef) in params.enumerated() {
                let (tp, optional) = paramDef
                result += tp.name + (optional ? "?" : "")
                
                if i < params.count-1 {
                    result += ", "
                }
            }
            
            result += ":"

            if let returns = ret {
                result += " " + returns.name
            }
            
            result += ">"
            
            return result
        }
        
        fileprivate override init(name: String, type tp: TypeSymbol? = nil) {
            super.init(name: name, type: tp)
        }
    }
    
    class NativeFunctionTypeSymbol : FunctionTypeSymbol {
        static let shared = NativeFunctionTypeSymbol(name: "native_function")
    }
    
    class ScriptedFunctionTypeSymbol: FunctionTypeSymbol {
        var returnType: TypeSymbol?
        var argTypes: [ArgumentDefinition]
        
        convenience init(ret: TypeSymbol?, args: [ArgumentDefinition]) {
            self.init(Self.constructFunctionName(ret: ret, params: args), ret: ret, args: args)
        }
        
        init(_ name: String, ret: TypeSymbol?, args: [ArgumentDefinition]) {
            argTypes = args
            returnType = ret
            super.init(name: name, type: nil)
        }
    }
    
    public class NativeFunctionSymbol : Symbol {
        public enum ArgType {
            case none
            case any
            case some(UInt)
            case someOrLess(UInt)
        }

        public typealias NativeFunctionValidation = ([Node], SemanticAnalyzer) throws -> TypeSymbol?
        
        var body: NativeFunctionValue?
        
        var semanticTest: NativeFunctionValidation = {_, _ in
            nil
        }
        
        var argCount: ArgType
        
        init(name: String, takes args: ArgType = .none, validation: NativeFunctionValidation?) {
            if let validation = validation { semanticTest = validation }
            argCount = args
            super.init(name: name, type: NativeFunctionTypeSymbol.shared)
        }
    }
    
    class ScriptedFunctionSymbol: Symbol {
        var value: ScriptedFunctionValue?

        init(name: String, type: ScriptedFunctionTypeSymbol, value: ScriptedFunctionValue? = nil) {
            self.value = value
            super.init(name: name, type: type)
        }
    }
    
    class VarSymbol: Symbol {
        var value: Value?
        
        init(name: String, type: TypeSymbol, value: Value? = nil) {
            self.value = value
            super.init(name: name, type: type)
            isInitialized = value != nil
        }
    }
    
    
    class SymbolTable {
        enum UnwindType {
            case `continue`
            case `return`
            case `break`
        }
        
        var unwindConditions: Set<UnwindType> = []
        
        private var unwindingFor: UnwindType?
        
        let name: String
        var parent: SymbolTable?
        
        private var topScope: SymbolTable {
            parent?.topScope ?? self
        }
        
        private var symbols: Dictionary<String, Symbol> = [:]
        
        var level: Int {
            parent == nil
                ? 0
                : parent!.level + 1
        }
        
        init(_ name: String, parent: SymbolTable? = nil) {
            self.name = name
            self.parent = parent
        }
        
        subscript(name: String, inParents: Bool = true) -> Symbol? {
            if let here = symbols[name] { return here }
            
            if inParents { return parent?[name] }
            
            return nil
        }
        
        func get(from node: Node?, andParents: Bool = true) throws -> Symbol? {
            guard let node = node else { return nil }
            switch node {
            case .variable(let name):
                if let found = symbols[name.lexeme] {
                    return found
                }
                if andParents {
                    return parent?[name.lexeme]
                }
            case .functionType(let args, let ret):
                let actualArgs = try args.map { argDef -> (TypeSymbol, Bool) in
                    let (type, isOptional) = argDef
                    guard let actualType = try self.get(from: type) as? TypeSymbol else {
                        throw OdoException.NameError(message: "Invalid type in function type arguments.")
                    }
                    
                    return (actualType, isOptional)
                }
                
                let returns: TypeSymbol?
                if let ret = ret {
                    guard let found = try get(from: ret) as? TypeSymbol else {
                        throw OdoException.NameError(message: "Invalid return type in function type arguments.")
                    }
                    
                    returns = found
                } else {
                    returns = nil
                }
                
                let funcName = FunctionTypeSymbol.constructFunctionName(ret: returns, params: actualArgs)
                if let functionType = self[funcName] as? ScriptedFunctionTypeSymbol {
                    return functionType
                } else {
                    let functionType = ScriptedFunctionTypeSymbol(funcName, ret: returns, args: actualArgs)
                    return topScope.addSymbol(functionType)
                }
            default:
                break
            }

            return nil
        }
        
        @discardableResult
        func addSymbol(_ sym: Symbol) -> Symbol? {
            if symbols.contains(where: { $0.key == sym.name }) {
                return nil
            }
            
            symbols[sym.name] = sym
            
            return sym
        }
        
        func removeSymbol(_ sym: Symbol) {
            if let indx = symbols.index(forKey: sym.name) {
                symbols.remove(at: indx)
            }
        }
        
        var unwindStatus: UnwindType? {
            unwindingFor
        }
        
        func unwind(to type: UnwindType) {
            unwindingFor = type
            if unwindConditions.contains(type) {
                return
            }
            
            parent?.unwind(to: type)
        }

        func canUnwind(to type: UnwindType) -> Bool {
            return unwindConditions.contains(type) || parent?.canUnwind(to: type) ?? false
        }
        
        func stopUnwinding() {
            unwindingFor = nil
        }

        func copy() -> SymbolTable {
            let table = SymbolTable(self.name, parent: self.parent)
            table.unwindConditions = self.unwindConditions
            table.symbols = self.symbols
            
            return table
        }
    }
    
}
