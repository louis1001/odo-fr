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
                ignoreNl()
            } else if currentToken.type != .eof {
                // if it's not any of the other terminators
                try eat(tp: .newLine)
                ignoreNl()
            }
        }
        
        func ignoreNl() {
            while currentToken.type == .newLine {
                // Doesn't throws. Only eats if certain
                try! eat(tp: .newLine)
            }
        }
        
        func block() throws -> Node {
            let result = try statementList()
            
            return .block(result)
        }
        
        func statementList() throws -> [Node] {
            var result: [Node] = []
            
            ignoreNl()
            
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
                result = try ternaryOp()
            }
            
            if withTerm {
                try statementTerminator()
            }
            
            return result
        }
        
        func getFullType() throws -> Node {
            var tp: Node = .noOp
            
            ignoreNl()
            
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
                ignoreNl()
                assignment = try ternaryOp()
            } else {
                assignment = .noOp
            }
            
            return .varDeclaration(type, name, assignment)
        }
        
        func ternaryOp() throws -> Node {
            var result: Node = try or()
            
            ignoreNl()
            
            while currentToken.type == .quest {
                try eat(tp: .quest)
                
                ignoreNl()
                
                let trueExpr = try or()
                
                ignoreNl()
                
                try eat(tp: .colon)
                
                ignoreNl()
                
                let falseExpr = try or()
                
                result = .ternaryOp(result, trueExpr, falseExpr)
            }
            
            return result
        }
        
        func or() throws -> Node {
            var result = try and()
            
            ignoreNl()
            
            while currentToken.type == .or {
                let op = currentToken
                try eat(tp: currentToken.type)
                
                ignoreNl()
                result = .logicOp(result, op, try and())
                
                ignoreNl()
            }
            
            return result
        }
        
        func and() throws -> Node {
            var result = try expression()
            
            ignoreNl()
            
            while currentToken.type == .and {
                let op = currentToken
                try eat(tp: currentToken.type)
                ignoreNl()
                result = .logicOp(result, op, try expression())
                ignoreNl()
            }
            
            return result
        }
        
        func expression() throws -> Node {
            var result = try term()
            
            ignoreNl()
            
            while   currentToken.type == .plus ||
                    currentToken.type == .minus {
                let op = currentToken
                try eat(tp: currentToken.type)
                
                ignoreNl()
                result = .arithmeticOp(result, op, try term())
                
                ignoreNl()
            }
            
            return result
        }
        
        func term() throws -> Node {
            var result = try postfix()
            
            ignoreNl()
            
            while   currentToken.type == .mul ||
                    currentToken.type == .div {
                let op = currentToken
                try eat(tp: currentToken.type)
                
                ignoreNl()
                result = .arithmeticOp(result, op, try postfix())
                ignoreNl()
            }
            
            return result
        }
        
        func postfix() throws -> Node {
            var result = try factor()
            
            ignoreNl()
            
//            while currentToken is one of the postfixes
            
            if currentToken.type == .assignment {
                try eat(tp: .assignment)
                result = .assignment(result, try ternaryOp())
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
            case .parOpen:
                try eat(tp: .parOpen)
                ignoreNl()
                let innerFactor = try ternaryOp()
                ignoreNl()
                try eat(tp: .parClose)
                return innerFactor
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
