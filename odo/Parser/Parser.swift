//
//  Parser.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    public class Parser {
        let lexer = Lexer()
        var currentToken: Token
        public init() {
            currentToken = Token(type: .eof)
        }
        
        func eat(tp: Token.Kind) throws {
            if currentToken.type == tp {
                currentToken = try lexer.getNextToken()
            } else {
                throw OdoException.SyntaxError(
                    message: "Unextected Token \"\(currentToken)\" found at line \(lexer.currentLine). Expected Token of type `\(tp)`")
            }
        }

        func program() throws -> Node {
            let result = try block()
            
            if currentToken.type != .eof {
                throw OdoException.SyntaxError(message: "Unextected Token \"\(currentToken)\" found at line \(lexer.currentLine).")
            }
            
            return result
        }
        
        func statementTerminator() throws {
            if currentToken.type == .semiColon {
                try eat(tp: .semiColon)
                while currentToken.type == .newLine {
                    try eat(tp: .newLine)
                }
            } else if currentToken.type != .eof {
                // if it's not any of the other terminators
                try eat(tp: .newLine)
                while currentToken.type == .newLine {
                    try eat(tp: .newLine)
                }
            }
        }
        
        func ignoreNl() throws {
            while currentToken.type == .newLine {
                try eat(tp: .newLine)
            }
        }
        
        func block() throws -> Node {
            let result = try statementList()
            
            return .block(result)
        }
        
        func statementList() throws -> [Node] {
            var result: [Node] = []
            
            try ignoreNl()
            
            while currentToken.type != .eof {
                result.append(try statement())
            }
            
            return result
        }
        
        func statement(withTerm: Bool = true) throws -> Node {
            var result: Node = .noOp
            switch currentToken.type {
            default:
                result = try or()
            }
            
            if withTerm {
                try statementTerminator()
            }
            
            return result
        }
        
        func or() throws -> Node {
            var result = try and()
            
            while currentToken.type == .or {
                let op = currentToken
                try eat(tp: currentToken.type)
                result = .logicOp(result, op, try and())
            }
            
            return result
        }
        
        func and() throws -> Node {
            var result = try expression()
            
            while currentToken.type == .and {
                let op = currentToken
                try eat(tp: currentToken.type)
                result = .logicOp(result, op, try expression())
            }
            
            return result
        }
        
        func expression() throws -> Node {
            var result = try term()
            
            while   currentToken.type == .plus ||
                    currentToken.type == .minus {
                let op = currentToken
                try eat(tp: currentToken.type)
                result = .arithmeticOp(result, op, try term())
            }
            
            return result
        }
        
        func term() throws -> Node {
            var result = try factor()
            
            while   currentToken.type == .mul ||
                    currentToken.type == .div {
                let op = currentToken
                try eat(tp: currentToken.type)
                result = .arithmeticOp(result, op, try factor())
            }
            
            return result
        }
        
        func factor() throws -> Node {
            switch currentToken.type {
            case .double:
                let token = currentToken
                try eat(tp: .double)
                return .double(token)
            case .int:
                let token = currentToken
                try eat(tp: .int)
                return .int(token)
            case .string:
                let token = currentToken
                try eat(tp: .string)
                return .string(token)
            case .true:
                try eat(tp: .true)
                return .true
            case .false:
                try eat(tp: .false)
                return .false
            default:
                break
            }

            throw OdoException.SyntaxError(message: "Unexpected token `\(currentToken)`")
        }
        
        func setText(to text: String) throws {
            lexer.setText(to: text)
            currentToken = try lexer.getNextToken()
        }
    }
}
