//
//  File.swift
//  
//
//  Created by Luis Gonzalez on 17/6/22.
//

import Foundation

extension Odo {
public struct NodeResult {
    var typeId: Int?
    init(_ typeId: Int) {
        self.typeId = typeId
    }
    
    init(_ primitive: TypeSymbol.Primitives) {
        self.typeId = primitive.rawValue
    }
    
    init() {
        self.typeId = nil
    }
}
}
