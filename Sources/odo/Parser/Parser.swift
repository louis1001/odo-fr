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
            case .const:
                try eat(tp: .const)
                result = try constDeclaration()
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
            case .return:
                try eat(tp: .return)
                let expr: Node?
                if currentToken.type != .eof &&
                    currentToken.type != .curlClose &&
                    currentToken.type != .semiColon &&
                    currentToken.type != .newLine {
                    expr = try ternaryOp()
                } else {
                    expr = nil
                }

                result = .returnStatement(expr)
            case .module:
                try eat(tp: .module)
                ignoreNl()
                let name = currentToken.lexeme
                try eat(tp: .identifier)
                ignoreNl()
                try eat(tp: .curlOpen)
                ignoreNl()
                let body = try statementList()
                try eat(tp: .curlClose)
                result = .module(name!, body)
                
            case .enum:
                try eat(tp: .enum)
                ignoreNl()
                let name = currentToken.lexeme
                try eat(tp: .identifier)
                ignoreNl()
                var body: [String] = []
                try eat(tp: .curlOpen)
                ignoreNl()
                while currentToken.type != .curlClose {
                    let name = currentToken.lexeme
                    try eat(tp: .identifier)
                    body.append(name!)
                    try statementTerminator()
                    ignoreNl()
                }
                try eat(tp: .curlClose)
                result = .enum(name!, body)
            default:
                result = try ternaryOp()
            }
            
            if withTerm {
                try statementTerminator()
            }
            
            return result
        }
        
        func getFunctionType() throws -> Node {
            try eat(tp: .lessThan)
            
            var arguments: [(Node, Bool)] = []
            
            var first = true
            while currentToken.type != .colon {
                if !first { try eat(tp: .comma) }
                else { first = false }
                let arg = try getFullType()
                ignoreNl()
                
                let isOptional = currentToken.type == .quest
                if isOptional {
                    try eat(tp: .quest)
                    ignoreNl()
                }
                
                arguments.append((arg, isOptional))
                ignoreNl()
            }
            
            try eat(tp: .colon)
            ignoreNl()
            
            let returnType: Node?
            if currentToken.type != .greaterThan {
                returnType = try getFullType()
                ignoreNl()
            } else {
                returnType = nil
            }
            
            try eat(tp: .greaterThan)
            return .functionType(arguments, returnType)
        }
        
        func getFullType() throws -> Node {
            var tp: Node = .noOp
            
            ignoreNl()
            
            if currentToken.type == .identifier {
                let name = currentToken.lexeme
                try eat(tp: .identifier)
                tp = .variable(name!)
                
                // while currentToken is ::
                // make tp a static variable node
            } else if currentToken.type == .lessThan {
                tp = try getFunctionType()
            } else {
                throw OdoException.SyntaxError(
                    message: "Unexpected token `\(currentToken)`. Expected a type for variable declaration"
                )
            }
            
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
            
            var id: String?
            if currentToken.type == .identifier {
                id = currentToken.lexeme
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
            let name = currentToken.lexeme
            try eat(tp: .identifier)
            
            ignoreNl()

            try eat(tp: .parOpen)
            ignoreNl()
            var declarations = [Node]()
            while currentToken.type == .identifier {
                declarations.append(try declaration())
                ignoreNl()
                if currentToken.type != .parClose {
                    try eat(tp: .comma)
                    ignoreNl()
                }
            }
            try eat(tp: .parClose)
            ignoreNl()
            
            var returnType: Node?
            if currentToken.type == .colon {
                try eat(tp: .colon)
                returnType = try getFullType()
            }
            
            ignoreNl()
            try eat(tp: .curlOpen)
            ignoreNl()
            let body = try functionBody()
            try eat(tp: .curlClose)
            
            return .functionDeclaration(name!, declarations, returnType, body)
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
        
        func constDeclaration() throws -> Node {
            let name = currentToken.lexeme
            try eat(tp: .identifier)
            
            let type: Node
            
            let withType = currentToken.type == .colon
            
            if withType {
                try eat(tp: .colon)
                
                type = try getFullType()
            } else {
                // TODO: Make this nil, and clear any to be actually generic
                type = .variable("any")
            }
            
            let assignment: Node?
            if !withType || currentToken.type == .assignment {
                try eat(tp: .assignment)
                ignoreNl()
                assignment = try ternaryOp()
            } else {
                assignment = nil
            }
            
            return .varDeclaration(type, name!, assignment, true)
        }
        
        func declaration(forceType: Bool = false) throws -> Node {
            let name = currentToken.lexeme
            try eat(tp: .identifier)
            
            let type: Node
            
            if forceType || currentToken.type == .colon {
                try eat(tp: .colon)
                
                type = try getFullType()
            } else {
                // TODO: Make this nil, and clear any to be actually generic
                type = .variable("any")
            }
            
            let assignment: Node?
            if currentToken.type == .assignment {
                try eat(tp: .assignment)
                ignoreNl()
                assignment = try ternaryOp()
            } else {
                assignment = nil
            }
            
            return .varDeclaration(type, name!, assignment)
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
            while currentToken.type == .parOpen ||
                    currentToken.type == .doubleColon {
                switch currentToken.type {
                case .parOpen:
                    try eat(tp: .parOpen)
                    let args = try callArgs()
                    ignoreNl()
                    try eat(tp: .parClose)
                    result = .functionCall(result, nil, args)
                    
                case .doubleColon:
                    try eat(tp: .doubleColon)
                    let name = currentToken.lexeme
                    try eat(tp: .identifier)
                    
                    result = .staticAccess(result, name!)
                default:
                    break
                }
            }
            
            if currentToken.type == .assignment {
                switch result {
                case .variable, .staticAccess:
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
                let name = currentToken.lexeme
                try eat(tp: .double)
                return .double(name!)
            case .int:
                let name = currentToken.lexeme
                try eat(tp: .int)
                return .int(name!)
            case .text:
                let name = currentToken.lexeme
                try eat(tp: .text)
                return .text(name!)
            case .true:
                try eat(tp: .true)
                return .true
            case .false:
                try eat(tp: .false)
                return .false
            case .identifier:
                let name = currentToken.lexeme
                try eat(tp: .identifier)
                return .variable(name!)
            case .parOpen:
                try eat(tp: .parOpen)
                ignoreNl()
                let innerFactor = try ternaryOp()
                ignoreNl()
                try eat(tp: .parClose)
                return innerFactor
            case .plus, .minus:
                let op = currentToken
                try eat(tp: currentToken.type)
                return .unaryOp(op, try postfix())
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
