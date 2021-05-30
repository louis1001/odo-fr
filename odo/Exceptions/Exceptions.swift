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
            case .SyntaxError(message: let message):
                result += message
            case .NameError(message: let message):
                result += message
            case .TypeError(message: let message):
                result += message
            case .RuntimeError(message: let message):
                result += message
            case .ValueError(message: let message):
                result += message
            case .OutOfRangeError(message: let message):
                result += message
            }

            return result
        }
    }
}
