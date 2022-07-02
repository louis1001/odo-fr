//
//  File.swift
//  
//
//  Created by Luis Gonzalez on 19/6/22.
//

import Foundation

extension Odo {
public indirect enum CheckedAst {
    case int(Int)
    case double(Double)
    case text(String)
    case truth(Bool)
    
    case `break`
    case `continue`

    case arithmeticOp(CheckedAst, Token, CheckedAst)
    
    case variable(String)
    case varDeclaration(Int, String, CheckedAst?, Bool)
    case assignment(CheckedAst, CheckedAst)
    
    case block([CheckedAst])
    
    case symbolAccess(Int)
    
    case noOp
}
}
