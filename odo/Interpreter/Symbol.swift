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
        var value: Value?
        
        var name: String
        
        var isType: Bool { false }
        
        init(type: TypeSymbol, name: String, value: Value? = nil) {
            self.name = name
            self.type = type
            self.value = value
        }
        
        fileprivate init(name: String, value: Value? = nil) {
            self.type = nil
            self.value = value
            self.name = name
        }
        
        func toString() -> String {
            return "Type(\(name))"
        }
        
        // Builtin types
        static let nullType     = PrimitiveTypeSymbol(name: "$nullType")
        static let boolType     = PrimitiveTypeSymbol(name: "bool")
        static let stringType   = PrimitiveTypeSymbol(name: "string")
        
        static let intType: PrimitiveTypeSymbol     = {
            let val = PrimitiveTypeSymbol(name: "int")
            val.isNumeric = true
            return val
        }()

        static let doubleType: PrimitiveTypeSymbol  = {
            let val = PrimitiveTypeSymbol(name: "double")
            val.isNumeric = true
            return val
        }()
    }

    class TypeSymbol: Symbol {
        override var isType: Bool { true }
        var isPrimitive: Bool { false }
        
        fileprivate(set) var isNumeric = false
        
        init(type: TypeSymbol?, name: String) {
            super.init(name: name)
        }
    }
    
    class PrimitiveTypeSymbol: TypeSymbol {
        override var isPrimitive: Bool { true }
        init(name: String) {
            super.init(type: nil, name: name)
        }
    }
}
