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
            currentToken = Token(type: .EOF)
        }
        
        func eat(tp: Token.Kind) throws {
            if currentToken.type == tp {
                currentToken = try lexer.getNextToken()
            } else {
                throw OdoException.SyntaxError(
                    message: "Unextected Token \"\(currentToken.toString())\" found at line \(lexer.currentLine). Expected Token of type `\(tp)`")
            }
        }

        func program() throws -> Node {
            let result = try block()
            
            if currentToken.type != .EOF {
                throw OdoException.SyntaxError(message: "Unextected Token \"\(currentToken.toString())\" found at line \(lexer.currentLine).")
            }
            
            return result
        }
        
        func block() throws -> Node {
            let result = try expression()
            
            return result
        }
        
        func expression() throws -> Node {
            var result = try term()
            
            while   currentToken.type == .Plus ||
                    currentToken.type == .Minus {
                let op = currentToken
                try eat(tp: currentToken.type)
                result = .ArithmeticOp(result, op, try term())
            }
            
            return result
        }
        
        func term() throws -> Node {
            var result = try factor()
            
            while   currentToken.type == .Mul ||
                    currentToken.type == .Div {
                let op = currentToken
                try eat(tp: currentToken.type)
                result = .ArithmeticOp(result, op, try factor())
            }
            
            return result
        }
        
        func factor() throws -> Node {
            switch currentToken.type {
            case .Double:
                let token = currentToken
                try eat(tp: .Double)
                return .TDouble(token)
            case .Integer:
                let token = currentToken
                try eat(tp: .Integer)
                return .Integer(token)
            case .String:
                let token = currentToken
                try eat(tp: .String)
                return .String(token)
            default:
                break
            }

            throw OdoException.SyntaxError(message: "Unexpected token `\(currentToken.toString())`")
        }
        
        func setText(to text: String) throws {
            lexer.setText(to: text)
            currentToken = try lexer.getNextToken()
        }
    }
}
