//
//  Value.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

extension Odo {
    public enum Value {
        case Int(Int)
        case NDouble(Double)
        case Null
        
        func isNumeric() -> Bool {
            switch self {
            case .Int(_), .NDouble(_):
                return true
            default:
                return false
            }
        }
        
        func asNumeric() -> Double? {
            switch self {
            case .NDouble(let x):
                return x
            case .Int(let x):
                return Double(x)
            default:
                return nil
            }
        }
    }
}
