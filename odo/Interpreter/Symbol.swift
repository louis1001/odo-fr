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
        
        init(name: String, type: TypeSymbol) {
            self.name = name
            self.type = type
        }
        
        fileprivate init(name: String) {
            self.type = nil
            self.name = name
        }
        
        func toString() -> String {
            return "Type(\(name))"
        }
        
        // Builtin types
        static let anyType      = PrimitiveTypeSymbol(name: "any")
        static let nullType     = PrimitiveTypeSymbol(name: "$nullType", type: .anyType)
        static let boolType     = PrimitiveTypeSymbol(name: "bool", type: .anyType)
        static let textType   = PrimitiveTypeSymbol(name: "text", type: .anyType)
        
        static let intType: PrimitiveTypeSymbol     = {
            let val = PrimitiveTypeSymbol(name: "int", type: .anyType)
            val.isNumeric = true
            return val
        }()

        static let doubleType: PrimitiveTypeSymbol  = {
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
    
    class PrimitiveTypeSymbol: TypeSymbol {
        override var isPrimitive: Bool { true }
        override init(name: String, type tp: TypeSymbol? = nil) {
            super.init(name: name, type: tp)
        }
    }
    
    class FunctionTypeSymbol: TypeSymbol {
        class func constructFunctionName(ret: TypeSymbol?, params: [(TypeSymbol, Bool)]) -> String {
            var result = "<"
            
            for (tp, optional) in params {
                result += tp.name + (optional ? "?" : "")
            }
            
            result += ":"
            
            if let returns = ret {
                result += returns.name
            }
            
            result += ">"
            
            return result
        }
        
        fileprivate override init(name: String, type tp: TypeSymbol? = nil) {
            super.init(name: name, type: tp)
        }
    }
    
    class ScriptFunctionTypeSymbol : FunctionTypeSymbol {
        init(ret: TypeSymbol?, params: [(TypeSymbol, Bool)]) {
            let name = FunctionTypeSymbol.constructFunctionName(ret: ret, params: params)
            super.init(name: name, type: ret)
        }
    }
    
    class NativeFunctionTypeSymbol : FunctionTypeSymbol {
        static let shared = NativeFunctionTypeSymbol(name: "native_function")
    }
    
    public class NativeFunctionSymbol : Symbol {
        public typealias NativeFunctionValidation = ([Node], SemanticAnalyzer) -> Result<TypeSymbol?, OdoException>
        
        var body: NativeFunctionValue?
        
        var semanticTest: NativeFunctionValidation = {_, _ in
            .success(nil)
        }
        
        init(name: String, validation: NativeFunctionValidation?) {
            if let validation = validation { semanticTest = validation }
            super.init(name: name, type: NativeFunctionTypeSymbol.shared)
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
        
        let name: String
        var parent: SymbolTable?
        private var unwindConditions: Set<UnwindType> = []
        
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
        
        @discardableResult
        func addSymbol(_ sym: Symbol) -> Symbol? {
            if symbols.contains(where: { $0.key == sym.name }) {
                return nil
            }
            
            symbols[sym.name] = sym
            
            return sym
        }
        
        func unwinds(for tag: UnwindType) {
            unwindConditions.insert(tag)
        }
        
        func unwind(toClosest tag: UnwindType) {
            if unwindConditions.contains(tag) {
                
            }
        }

    }
    
}
