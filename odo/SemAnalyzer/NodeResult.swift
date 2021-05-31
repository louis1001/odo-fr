//
//  NodeResult.swift
//  odo
//
//  Created by Luis Gonzalez on 30/5/21.
//

extension Odo {
    struct NodeResult {
        var tp: TypeSymbol?
        
        var isConstant = false
        var hasSideEffects = true
    }
}
