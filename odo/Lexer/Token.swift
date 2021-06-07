//
//  Token.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    
    public struct Token: CustomStringConvertible {
        public enum Kind {
            // Literals
            case int
            case double
            case text

            // Operators
            case plus
            case minus
            case mul
            case div
            
            case and
            case or
            
            case identifier
            
            // Keywords
            // Should I be naming them after keywords?
            // Sure. why not? FIXME
            case `true`
            case `false`
            case `var`
            
            // Punctuation
            case colon
            case semiColon
            case quest
            case parOpen
            case parClose
            
            case assignment
            
            case newLine

            case eof
        }
        
        public var type: Kind
        public var lexeme: String!
        
        public var description: String {
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
