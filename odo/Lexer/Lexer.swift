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
            "true": Token(type: .True),
            "false": Token(type: .False)
        ]
        
        private var text: String = ""
        
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
            if currentPos >= text.endIndex {
                return nil
            }
            return text[currentPos]
        }
        
        public init(text: String = "") {
            self.text = text
            self.currentPos = text.startIndex
        }
        
        func advance() {
            if currentChar?.isNewline ?? false {
                self._currentLine += 1
                self._currentColumn = 0
            } else {
                self._currentColumn += 1
            }
            currentPos = text.index(currentPos, offsetBy: 1)
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
                return Token(type: .Double, lexeme: result)
            } else {
                return Token(type: .Integer, lexeme: result)
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
        
        func string() throws -> Token {
            let openning = currentChar!
            var result = ""
            
            advance()
            
            while currentChar != openning {
                if currentChar == nil {
                    throw OdoException.SyntaxError(message: "String literal has no matching `\(openning)`.")
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

            return Token(type: .String, lexeme: result)
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
                return Token(type: .Identifier, lexeme: result)
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
                return Token(type: .EOF)
            }
            
            switch char {
            case let x where x.isNumber:
                return number()
            case let x where x.isLetter || x == "_":
                return identifier()
            case "+":
                advance()
                return Token(type: .Plus)
            case "-":
                advance()
                return Token(type: .Minus)
            case "*":
                advance()
                return Token(type: .Mul)
            case "/":
                advance()
                return Token(type: .Div)
            case "\"", "'":
                return try string()
            default:
                throw OdoException.InputError(line: currentLine, pos: currentColumn, character: char)
            }
        }
        
        public func setText(to text: String) {
            self.text = text
            self.currentPos = text.startIndex
            
            self._currentLine = 1
            self._currentColumn = 0
        }
    }
}
