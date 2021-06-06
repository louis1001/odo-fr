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
            "or": Token(type: .or)
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

        func ignoreWhitespace() {
            while isWhitespace() {
                advance()
            }
        }
        
        public func getNextToken() throws -> Token {
            ignoreWhitespace()
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
                return Token(type: .colon)
            case "=":
                advance()
                return Token(type: .assignment)
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
