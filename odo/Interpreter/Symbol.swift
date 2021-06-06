//
//  Symbol.swift
//  odo
//
//  Created by Luis Gonzalez on 30/5/21.
//

import Foundation

extension Odo {
    class Symbol: Equatable, Hashable {
        let id = UUID()
        static func == (lhs: Odo.Symbol, rhs: Odo.Symbol) -> Bool {
            return lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
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

    class TypeSymbol: Symbol {
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
    
    class VarSymbol: Symbol {
        var value: Value?
        
        init(name: String, type: TypeSymbol, value: Value? = nil) {
            self.value = value
            super.init(name: name, type: type)
            isInitialized = value != nil
        }
    }
    
    
    class SymbolTable {
        
        let name: String
        var parent: SymbolTable?
        
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
            symbols[name] ?? parent?[name]
        }
        
        @discardableResult
        func addSymbol(_ sym: Symbol) -> Symbol? {
            if symbols.contains(where: { $0.key == sym.name }) {
                return nil
            }
            
            symbols[sym.name] = sym
            
            return sym
        }

    }
    
}
