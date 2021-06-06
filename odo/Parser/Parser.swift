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
        
        func programContent() throws -> [Node]{
            return try statementList()
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
            case .var:
                try eat(tp: .var)
                result = try declaration()
            default:
                result = try or()
            }
            
            if withTerm {
                try statementTerminator()
            }
            
            return result
        }
        
        func getFullType() throws -> Node {
            var tp: Node = .noOp
            
            if currentToken.type == .identifier {
                tp = .variable(currentToken)
                try eat(tp: .identifier)
            /*} else if currentToken.type == .lessThan {
                // Maybe it's a function type
            */ } else {
                throw OdoException.SyntaxError(
                    message: "Unexpected token `\(currentToken)`. Expected a type for variable declaration"
                )
             }
            
            // while currentToken is ::
            // make tp a static variable node
            
            // while currentToken is [
            // make tp a index node
            
            return tp
        }
        
        func declaration(forceType: Bool = false) throws -> Node {
            // Refactor. var or let syntax instead of c-like
            let name = currentToken
            try eat(tp: .identifier)
            
            let type: Node
            
            if forceType || currentToken.type == .colon {
                try eat(tp: .colon)
                
                type = try getFullType()
            } else {
                type = .variable(Token(type: .identifier, lexeme: "any"))
            }
            
            let assignment: Node
            if currentToken.type == .assignment {
                try eat(tp: .assignment)
                assignment = try or()
            } else {
                assignment = .noOp
            }
            
            return .varDeclaration(type, name, assignment)
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
            var result = try postfix()
            
            while   currentToken.type == .mul ||
                    currentToken.type == .div {
                let op = currentToken
                try eat(tp: currentToken.type)
                result = .arithmeticOp(result, op, try postfix())
            }
            
            return result
        }
        
        func postfix() throws -> Node {
            var result = try factor()
            
//            while currentToken is one of the postfixes
            
            if currentToken.type == .assignment {
                try eat(tp: .assignment)
                result = .assignment(result, try or())
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
            case .text:
                let token = currentToken
                try eat(tp: .text)
                return .text(token)
            case .true:
                try eat(tp: .true)
                return .true
            case .false:
                try eat(tp: .false)
                return .false
            case .identifier:
                let name = currentToken
                try eat(tp: .identifier)
                return .variable(name)
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
