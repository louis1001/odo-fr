//
//  Lexer.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

import Foundation

extension Odo {
    public class Lexer {
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
        
        public func getNextToken() throws -> Token {
            guard let char = currentChar else {
                return Token(type: .EOF)
            }
            
            switch char {
            case let x where x.isNumber:
                return number()
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
