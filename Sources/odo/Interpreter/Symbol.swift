//
//  Symbol.swift
//  odo
//
//  Created by Luis Gonzalez on 30/5/21.
//

import Foundation

private class WeakPtr<T: AnyObject> {
    weak var value: T?
    
    var isNil: Bool { value == nil }
    
    init(_ value: T) {
        self.value = value
    }
}

extension Odo {
    public class Symbol: Hashable, Identifiable {
        public static func == (lhs: Odo.Symbol, rhs: Odo.Symbol) -> Bool {
            lhs.id == rhs.id
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        public let id = UUID()
        
        var type: TypeSymbol?
        private(set) weak var scope: SymbolTable?
        
        public let name: String
        var qualifiedName: String
        
        var isType: Bool { false }
        
        // Semantic Information
        var isInitialized = true
        var hasBeenChecked = true
        
        var onDestruction: (()->Void)?
        
        let isConstant: Bool
        
        init(name: String, type: TypeSymbol, isConstant: Bool = false) {
            self.name = name
            self.type = type
            self.isConstant = isConstant
            qualifiedName = name
        }
        
        fileprivate init(name: String, isConstant: Bool = false) {
            self.type = nil
            self.name = name
            self.isConstant = isConstant
            self.qualifiedName = name
        }
        
        deinit {
            onDestruction?()
        }
        
        func toString() -> String {
            return "Type(\(name))"
        }
        
        func setScope(_ scope: SymbolTable?) {
            self.scope = scope
            var qualification = scope?.qualifications ?? []
            qualification.append(name)
            qualifiedName = qualification.joined(separator: "::")
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
        
        override init(name: String, type: TypeSymbol?, isConstant: Bool = true) {
            super.init(name: name, isConstant: isConstant)
        }
    }
    
    public class PrimitiveTypeSymbol: TypeSymbol {
        override var isPrimitive: Bool { true }
        init(name: String, type tp: TypeSymbol? = nil) {
            super.init(name: name, type: tp, isConstant: true)
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
        
        fileprivate init(name: String, type tp: TypeSymbol? = nil) {
            super.init(name: name, type: tp, isConstant: true)
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
            case nothing
            case whatever
            case some(UInt)
            case someOrLess(UInt)
        }
        
        public enum ArgumentDescription {
            case any
            case int
            case double
            case bool
            case text
            case intOr(Int)
            case doubleOr(Double)
            case boolOr(Bool)
            case textOr(String)
            
            func get() -> ScriptedFunctionTypeSymbol.ArgumentDefinition {
                switch self {
                case .any:                  return (.anyType,       false)
                case .int, .intOr:          return (.intType,    isOptional())
                case .double, .doubleOr:    return (.doubleType, isOptional())
                case .bool, .boolOr:        return (.boolType,   isOptional())
                case .text, .textOr:        return (.textType,   isOptional())
                }
            }
            
            func getValue() -> Value? {
                switch self {
                case .any, .int, .double, .bool, .text: return nil
                case .intOr(let value):    return .literal(value)
                case .doubleOr(let value): return .literal(value)
                case .boolOr(let value):   return .literal(value)
                case .textOr(let value):   return .literal(value)
                }
            }
            
            func isOptional() -> Bool {
                switch self {
                case .any:      return false
                case .int:      return false
                case .double:   return false
                case .bool:     return false
                case .text:     return false
                case .intOr:    return true
                case .doubleOr: return true
                case .boolOr:   return true
                case .textOr:   return true
                }
            }
        }

        public typealias NativeFunctionValidation = ([Node], SemanticAnalyzer) throws -> TypeSymbol?
        
        var body: NativeFunctionValue?
        
        var semanticTest: NativeFunctionValidation = {_, _ in
            nil
        }
        
        var argCount: ArgType
        
        init(name: String, takes args: ArgType = .nothing, validation: NativeFunctionValidation?) {
            if let validation = validation { semanticTest = validation }
            argCount = args
            super.init(name: name, type: NativeFunctionTypeSymbol.shared, isConstant: true)
        }
    }
    
    class ScriptedFunctionSymbol: Symbol {
        var value: ScriptedFunctionValue?

        init(name: String, type: ScriptedFunctionTypeSymbol, value: ScriptedFunctionValue? = nil) {
            self.value = value
            super.init(name: name, type: type)
        }
    }
    
    class ModuleSymbol: Symbol {
        var value: ModuleValue?
        init(name: String, value: ModuleValue? = nil) {
            self.value = value
            super.init(name: name, isConstant: true)
        }
    }
    
    class EnumSymbol: TypeSymbol {
        var value: EnumValue?
        init(name: String, value: EnumValue? = nil) {
            self.value = value
            super.init(name: name, type: nil)
        }
    }
    
    class EnumCaseSymbol: Symbol {
        var value: EnumCaseValue?
        init(name: String, type: EnumSymbol, value: EnumCaseValue? = nil) {
            self.value = value
            super.init(name: name, type: type, isConstant: true)
        }
    }
    
    class VarSymbol: Symbol {
        var value: Value?
        
        init(name: String, type: TypeSymbol, value: Value? = nil, isConstant: Bool = false) {
            self.value = value
            super.init(name: name, type: type, isConstant: isConstant)
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
        
        private var children: [WeakPtr<SymbolTable>] = []
        
        let name: String
        var parent: SymbolTable? {
            willSet {
                parent?.children.removeAll { $0.value === self || $0.isNil }
                newValue?.children.append(WeakPtr(self))
            }
        }
        
        var qualifications: [String] {
            var qu = self.parent?.qualifications ?? []
            if let owner = self.owner {
                qu.append(owner.name)
            }
            
            return qu
        }
        
        weak var owner: Symbol? {
            didSet {
                updateScope()
            }
        }
        private(set) var qualifiedScopeName: String = ""
        
        private var topScope: SymbolTable {
            parent?.topScope ?? self
        }
        
        func updateScope() {
            self.makeQualifiedScopeName()
            self.forEach {_, sym in
                sym.setScope(self)
            }
            
            for scope in self.children {
                scope.value?.updateScope()
            }
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
            
            self.makeQualifiedScopeName()
        }
        
        private func makeQualifiedScopeName() {
            self.qualifiedScopeName = qualifications.joined(separator: "::")
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
                if let found = self[name] {
                    return found
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
            case .staticAccess(let expr, let name):
                guard let leftHand = try get(from: expr) else {
                    throw OdoException.ValueError(message: "Invalid static access on unknown symbol")
                }
                
                switch leftHand {
                case let asModule as ModuleSymbol:
                    let moduleContext = asModule.value
                    return moduleContext?.scope[name]
                case let asEnum as EnumSymbol:
                    let enumContext = asEnum.value
                    return enumContext?.scope[name]
                default:
                    // Innaccessible, based on semantic analysis
                    break
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
            
            sym.setScope(self)
            
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
        
        func forEach(body: (String, Symbol) -> Void) {
            for (name, sym) in symbols {
                body(name, sym)
            }
        }
        
        func forEach(body: (String, Symbol) throws -> Void) rethrows {
            for (name, sym) in symbols {
                try body(name, sym)
            }
        }
    }
    
}
