//
//  Token.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    
    public struct Token {
        public enum Kind {
            // Literals
            case Integer
            case Double
            case String

            // Operators
            case Plus
            case Minus
            case Mul
            case Div
            
            case Identifier
            
            // Keywords
            case True
            case False

            case EOF
        }
        
        public var type: Kind
        public var lexeme: String!
        
        public func toString() -> String {
            let valueString: String
            if lexeme == nil {
                valueString = ""
            } else {
                valueString = "{'\(lexeme!)'}"
            }
            
            return "\(type)\(valueString)"
        }
    }
}
