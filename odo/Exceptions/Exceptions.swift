//
//  Exceptions.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    public enum OdoException : Error {
        typealias RawValue = Int

        case InputError(line: Int, pos: Int, character: Character)
        case SyntaxError(message: String)
        case NameError(message: String)
        case TypeError(message: String)
        case RuntimeError(message: String)
        case ValueError(message: String)
        case OutOfRangeError(message: String)
        case SemanticError(message: String)
        
        func name() -> String {
            let n = String(describing: self)
            let endOfPar = n.firstIndex(of: "(") ?? n.endIndex
            return String(n[..<endOfPar])
        }
        
        public func description() -> String {
            var result = "\(self.name()):\n\t"
            switch self {
            case .InputError(let line, let pos, let char):
                result += "Invalid character `\(char)` at line \(line), column \(pos)"
            case .SyntaxError(let message),
                 .NameError(let message),
                 .TypeError(let message),
                 .RuntimeError(let message),
                 .ValueError(let message),
                 .OutOfRangeError(let message),
                 .SemanticError(let message):
                result += message
            }

            return result
        }
    }
}
