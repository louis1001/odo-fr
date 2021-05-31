//
//  Token.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    
    public struct Token {
        public enum Kind {
            case Integer
            case Double
            case String

            case Plus
            case Minus
            case Mul
            case Div

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
