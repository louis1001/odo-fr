//
//  ast.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//
import Foundation

extension Odo {
    indirect enum Node {
        case int(Token)
        case double(Token)
        case string(Token)
        
        // FIXME: What should I use instead of the straight up keywords?
        case `true`
        case `false`
        
        case arithmeticOp(Node, Token, Node)
        case logicOp(Node, Token, Node)
        
        case noOp
        
        
        func isNumeric() -> Bool {
            switch self {
            case .int, .double:
                return true
            default:
                return false
            }
        }
    }
}
