//
//  Lexer.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

import Foundation

extension Odo {
    public class Lexer {
        
        static let keyWords: [String: Token] = [
            "true": Token(type: .true),
            "false": Token(type: .false),
            "and": Token(type: .and),
            "or": Token(type: .or),
            "var": Token(type: .var),
            "const": Token(type: .const),
            "if": Token(type: .if),
            "else": Token(type: .else),
            
            "loop": Token(type: .loop),
            "while": Token(type: .while),
            "forange": Token(type: .forange),
            
            "func": Token(type: .func),
            "return": Token(type: .return),
            
            "break": Token(type: .break),
            "continue": Token(type: .continue),
            
            "module": Token(type: .module),
            "enum": Token(type: .enum)
        ]
        
        private var code: String = ""
        
        private var currentPos: String.Index
        
        private var _currentLine: Int = 1
        public var currentLine: Int {
            _currentLine
        }

        private var _currentColumn: Int = 0
        public var currentColumn: Int {
            return _currentColumn
        }
        
        private var currentChar: Character? {
            if currentPos >= code.endIndex {
                return nil
            }
            return code[currentPos]
        }
        
        public init(text: String = "") {
            self.code = text
            self.currentPos = text.startIndex
        }
        
        func advance() {
            if currentChar?.isNewline ?? false {
                self._currentLine += 1
                self._currentColumn = 0
            } else {
                self._currentColumn += 1
            }
            currentPos = code.index(currentPos, offsetBy: 1)
        }
        
        func isWhitespace() -> Bool {
            guard let currentChar = currentChar else { return false }

            return currentChar.isWhitespace && !currentChar.isNewline
        }
        
        func number() -> Token {
            var result = String(currentChar!)
            
            advance()
            
            var foundPoint = false
            while currentChar?.isNumber ?? false ||
                 (!foundPoint && currentChar == ".")
            {
                if currentChar == "." { foundPoint = true }
                result.append(currentChar!)
                advance()
            }
            
            if foundPoint {
                return Token(type: .double, lexeme: result)
            } else {
                return Token(type: .int, lexeme: result)
            }
        }
        
        func escapeChar() -> Character {
            let escapeMap: [Character: Character] = [
                "\\": "\\",
                "n" : "\n",
                "r" : "\r",
                "t" : "\t",
//                "b" : "\b",
//                "a" : "\a",
//                "v" : "\v",
                "\'": "\'",
                "\"": "\"",
//                "?" : "\?",
            ]
            
            let toEscape = currentChar!
            
            if let escaped = escapeMap[toEscape] {
                return escaped
            } else {
                return toEscape
            }
        }
        
        func text() throws -> Token {
            let openning = currentChar!
            var result = ""
            
            advance()
            
            while currentChar != openning {
                if currentChar == nil {
                    throw OdoException.SyntaxError(message: "Text literal has no matching `\(openning)`.")
                }

                if currentChar == "\\" {
                    advance()
                    result.append(escapeChar())
                } else {
                    result.append(currentChar!)
                }
                
                advance()
            }
            
            advance()

            return Token(type: .text, lexeme: result)
        }
        
        func identifier() -> Token {
            var result = "\(currentChar!)"
            advance()
            
            while let char = currentChar,
                  char.isLetter || char.isNumber || char == "_" {
                result.append(currentChar!)
                advance()
            }
            
            if let keyword = Self.keyWords[result] {
                return keyword
            } else {
                return Token(type: .identifier, lexeme: result)
            }
        }
        
        func ignoreComment() throws {
            if currentChar == "{" {
                advance()
                while true {
                    guard let char = currentChar else {
                        throw OdoException.SyntaxError(message: "Missing end of commend `}#`.")
                    }
                    
                    if char == "}" {
                        advance()
                        if currentChar == "#" {
                            advance()
                            return
                        }
                    }
                    
                    if char == "#" {
                        advance()
                        if currentChar == "{" {
                            try ignoreComment()
                        }
                    }
                    
                    advance()
                }
            } else {
                while let char = currentChar, !char.isNewline {
                    advance()
                }
            }
        }

        func ignoreWhitespace() {
            while isWhitespace() {
                advance()
            }
        }
        
        public func getNextToken() throws -> Token {
            ignoreWhitespace()
            if currentChar == "#" {
                advance()
                try ignoreComment()
                ignoreWhitespace()
            }
            guard let char = currentChar else {
                return Token(type: .eof)
            }
            
            switch char {
            case let x where x.isNumber:
                return number()
            case let x where x.isLetter || x == "_":
                return identifier()
            case let x where x.isNewline:
                advance()
                return Token(type: .newLine)
            case "+":
                advance()
                return Token(type: .plus)
            case "-":
                advance()
                return Token(type: .minus)
            case "*":
                advance()
                return Token(type: .mul)
            case "/":
                advance()
                return Token(type: .div)
            case "\"", "'":
                return try text()
            case ";":
                advance()
                return Token(type: .semiColon)
            case ":":
                advance()
                if currentChar == ":" {
                    advance()
                    return Token(type: .doubleColon)
                } else {
                    return Token(type: .colon)
                }
            case ",":
                advance()
                return Token(type: .comma)
            case "~":
                advance()
                return Token(type: .tilde)
            case "=":
                advance()
                
                switch currentChar {
                case "=":
                    advance()
                    return Token(type: .equals)
                default:
                    return Token(type: .assignment)
                }
            case ">":
                advance()
                
                switch currentChar {
                case "=":
                    advance()
                    return Token(type: .greaterOrEqualTo)
                default:
                    return Token(type: .greaterThan)
                }
            case "<":
                advance()
                
                switch currentChar {
                case "=":
                    advance()
                    return Token(type: .lessOrEqualTo)
                default:
                    return Token(type: .lessThan)
                }
            case "!":
                advance()
                if currentChar == "=" {
                    advance()
                    return Token(type: .notEquals)
                }
                throw OdoException.InputError(line: currentLine, pos: currentColumn, character: "!")
            case "?":
                advance()
                return Token(type: .quest)
            case "(":
                advance()
                return Token(type: .parOpen)
            case ")":
                advance()
                return Token(type: .parClose)
            case "{":
                advance()
                return Token(type: .curlOpen)
            case "}":
                advance()
                return Token(type: .curlClose)
            default:
                throw OdoException.InputError(line: currentLine, pos: currentColumn, character: char)
            }
        }
        
        public func setText(to text: String) {
            self.code = text
            self.currentPos = text.startIndex
            
            self._currentLine = 1
            self._currentColumn = 0
        }
    }
}
