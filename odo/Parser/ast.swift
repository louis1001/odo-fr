//
//  ast.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//
import Foundation

extension Odo {
    public indirect enum Node {
        case int(Token)
        case double(Token)
        case text(Token)
        
        // FIXME: What should I use instead of the straight up keywords?
        case `true`
        case `false`
        
        case `break`
        case `continue`
        
        case block([Node])
        
        case arithmeticOp(Node, Token, Node)
        case logicOp(Node, Token, Node)
        case equalityOp(Node, Token, Node)
        case relationalOp(Node, Token, Node)
        
        case ternaryOp(Node, Node, Node)
        
        case variable(Token)
        case varDeclaration(Node, Token, Node?)
        case assignment(Node, Node)
        
        case functionDeclaration(Token, [Node], Node?, Node)
        case functionBody([Node])
        case functionCall(Node, Token?, [Node])
        
        case returnStatement(Node?)
        
        case module(Token, [Node])
        
        case staticAccess(Node, Token)
        
        case ifStatement(Node, Node, Node?)
        
        case loop(Node)
        case `while`(Node, Node)
        case forange (Token?, Node, Node?, Node, Bool)
        
        // MARK: - Type nodes
        case functionType([(Node, Bool)], Node?)
        
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
