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
            } else if currentToken.type != .eof &&
                        currentToken.type != .curlClose &&
                        currentToken.type != .parClose {
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
            
            while currentToken.type != .eof && currentToken.type != .curlClose {
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
            case .if:
                try eat(tp: .if)
                result = try ifStatement()
            case .curlOpen:
                try eat(tp: .curlOpen)
                result = try block()
                try eat(tp: .curlClose)
            case .loop:
                try eat(tp: .loop)
                try eat(tp: .curlOpen)
                result = .loop(try block())
                try eat(tp: .curlClose)
            case .while:
                try eat(tp: .while)
                result = try whileStatement()
            case .forange:
                try eat(tp: .forange)
                result = try forangeStatement()
                
            case .func:
                try eat(tp: .func)
                result = try funcDeclaration()
                
            case .break:
                try eat(tp: .break)
                result = .break
            case .continue:
                try eat(tp: .continue)
                result = .continue
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
        
        func ifStatement() throws -> Node {
            let condition = try ternaryOp()
            ignoreNl()
            
            if currentToken.type == .curlOpen {
                try eat(tp: .curlOpen)
                ignoreNl()
                
                let body = try block()
                
                ignoreNl()
                
                try eat(tp: .curlClose)
                ignoreNl()
                
                let falseBody: Node?
                if currentToken.type == .else {
                    try eat(tp: .else)
                    ignoreNl()
                    
                    if currentToken.type == .if {
                        try eat(tp: .if)
                        ignoreNl()
                        falseBody = try ifStatement()
                    } else {
                        try eat(tp: .curlOpen)
                        ignoreNl()
                        falseBody = try block()
                        ignoreNl()
                        try eat(tp: .curlClose)
                    }
                } else {
                    falseBody = nil
                }
                
                return .ifStatement(condition, body, falseBody)
            }
            
            return .noOp
        }
        
        func whileStatement() throws -> Node {
            let cond = try ternaryOp()
            
            try eat(tp: .curlOpen)
            let body = try block()
            try eat(tp: .curlClose)
            
            return .while(cond, body)
        }
        
        func forangeStatement() throws -> Node {
            let hasParents = currentToken.type == .parOpen
            
            ignoreNl()
            if hasParents {
                try eat(tp: .parOpen)
                ignoreNl()
            }
            
            var id: Token?
            if currentToken.type == .identifier {
                id = currentToken
                try! eat(tp: .identifier)
            }
            
            ignoreNl()
            
            let isReversed = currentToken.type == .tilde
            if isReversed {
                try eat(tp: .tilde)
                ignoreNl()
            }
            
            try eat(tp: .colon)
            ignoreNl()
            
            let firstExpr = try ternaryOp()
            var secondExpr: Node?
            
            if currentToken.type == .comma {
                try eat(tp: .comma)
                ignoreNl()
                secondExpr = try ternaryOp()
            }
            
            if hasParents {
                ignoreNl()
                try eat(tp: .parClose)
                ignoreNl()
            }
            
            let body = try statement(withTerm: false)
            
            return .forange(id, firstExpr, secondExpr, body, isReversed)
        }
        
        func funcDeclaration() throws -> Node {
            ignoreNl()
            let name = currentToken
            try eat(tp: .identifier)
            
            ignoreNl()

            try eat(tp: .parOpen)
            ignoreNl()
            var declarations = [Node]()
            while currentToken.type == .identifier {
                declarations.append(try declaration())
                ignoreNl()
            }
            try eat(tp: .parClose)
            
            ignoreNl()
            try eat(tp: .curlOpen)
            ignoreNl()
            let body = try functionBody()
            try eat(tp: .curlClose)
            
            return .functionDeclaration(name, declarations, nil, body)
        }
        
        func functionBody() throws -> Node {
            let content = try statementList()
            return .functionBody(content)
        }
        
        func callArgs() throws -> [Node] {
            var argsList: [Node] = []
            
            while currentToken.type != .parClose {
                argsList.append(try ternaryOp())
                ignoreNl()
                if currentToken.type != .parClose {
                    try eat(tp: .comma)
                    ignoreNl()
                }
            }

            return argsList
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
            
            let assignment: Node?
            if currentToken.type == .assignment {
                try eat(tp: .assignment)
                ignoreNl()
                assignment = try ternaryOp()
            } else {
                assignment = nil
            }
            
            return .varDeclaration(type, name, assignment)
        }
        
        func ternaryOp() throws -> Node {
            var result: Node = try or()
            
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
            
            while currentToken.type == .or {
                let op = currentToken
                try eat(tp: currentToken.type)
                
                ignoreNl()
                result = .logicOp(result, op, try and())
            }
            
            return result
        }
        
        func and() throws -> Node {
            var result = try equality()
            
            while currentToken.type == .and {
                let op = currentToken
                try eat(tp: currentToken.type)
                ignoreNl()
                result = .logicOp(result, op, try equality())
            }
            
            return result
        }
        
        func equality() throws -> Node {
            var result = try relation()
            
            while currentToken.type == .equals ||
                  currentToken.type == .notEquals {
                let op = currentToken
                try eat(tp: currentToken.type)
                ignoreNl()
                result = .equalityOp(result, op, try relation())
            }
            
            return result
        }
        
        func relation() throws -> Node {
            var result = try expression()
            
            while currentToken.type == .lessThan ||
                    currentToken.type == .lessOrEqualTo ||
                    currentToken.type == .greaterThan ||
                    currentToken.type == .greaterOrEqualTo {
                let op = currentToken
                try! eat(tp: op.type)
                
                ignoreNl()
                result = .relationalOp(result, op, try expression())
            }
            
            return result
        }
        
        func expression() throws -> Node {
            var result = try term()
            
            while   currentToken.type == .plus ||
                    currentToken.type == .minus {
                let op = currentToken
                try eat(tp: currentToken.type)
                
                ignoreNl()
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
                
                ignoreNl()
                result = .arithmeticOp(result, op, try postfix())
            }
            
            return result
        }
        
        func postfix() throws -> Node {
            var result = try factor()
            
//            while currentToken is one of the postfixes
            while currentToken.type == .parOpen {
                try eat(tp: .parOpen)
                let args = try callArgs()
                ignoreNl()
                try eat(tp: .parClose)
                result = .functionCall(result, nil, args)
            }
            
            if currentToken.type == .assignment {
                switch result {
                case .variable(_):
                    break
                default:
                    throw OdoException.SyntaxError(message: "Invalid assignment to non-variable")
                }
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
