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
            
            case equals
            case notEquals
            case lessThan
            case greaterThan
            case lessOrEqualTo
            case greaterOrEqualTo
            
            case and
            case or
            
            case identifier
            
            // MARK: Keywords
            // Should I be naming them after keywords?
            // Sure. why not? FIXME
            case `true`
            case `false`
            case `var`
            case const
            case `if`
            case `else`
            case loop
            case `while`
            case forange
            
            case `break`
            case `continue`
            
            case `func`
            case `return`
            
            case module
            
            // Punctuation
            case colon
            case semiColon
            case doubleColon
            case comma
            case tilde
            case quest
            case parOpen
            case parClose
            case curlOpen
            case curlClose
            
            case assignment
            
            case newLine

            case nothing
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
