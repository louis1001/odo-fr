//
//  File.swift
//  
//
//  Created by Luis Gonzalez on 17/6/22.
//

import Foundation

extension Odo {
struct TypeId: Hashable {
    var id: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class Symbol {
    var name: String
    var type: Int?
    
    var id: Int! = nil
    
    var isPrimitive: Bool { false }
    var isConstant: Bool = false

    var associatedScopeId: Int? = nil
    
    init(_ name: String, type: Int?) {
        self.name = name
        self.type = type
    }
    
    func setType(_ type: TypeSymbol) {
        self.type = type.id
    }
}

class TypeSymbol: Symbol {
    override init(_ name: String, type: Int? = nil) {
        super.init(name, type: type)

        self.isConstant = true
    }
}
    
class PrimitiveTypeSymbol: TypeSymbol {
    override var isPrimitive: Bool { true }
}

class VarSymbol: Symbol {
    
}

class EnumTypeSymbol: TypeSymbol {

}

class EnumSymbol: Symbol {

}

}

extension Odo.TypeSymbol {
    enum Primitives: Int {
        case any = 0
        
        case int
        case double
        case text
        case truth
    }
}
