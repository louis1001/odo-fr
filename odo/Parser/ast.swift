//
//  ast.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//
import Foundation

extension Odo {
    indirect enum Node {
        case Integer(Token)
        case TDouble(Token)
        case String(Token)
        
        case True
        case False
        
        case ArithmeticOp(Node, Token, Node)
        case LogicOp(Node, Token, Node)
        
        case NoOp
        
        
        func isNumeric() -> Bool {
            switch self {
            case .Integer, .TDouble:
                return true
            default:
                return false
            }
        }
    }
}
