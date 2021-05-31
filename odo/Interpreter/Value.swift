//
//  Value.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

import Foundation

extension Odo {
    public class Value: Identifiable {
        public let id = UUID()
        final var type: TypeSymbol!
        var isPrimitive: Bool { false }

        static let null: PrimitiveValue = {
            let val = PrimitiveValue()
            val.type = .nullType
            return val
        }()
        
        final class func primitive(_ value: Int) -> IntValue {
            return IntValue(value: value)
        }
        
        final class func primitive(_ value: Double) -> DoubleValue {
            return DoubleValue(value: value)
        }
        
        final class func primitive(_ value: String) -> StringValue {
            return StringValue(value: value)
        }
        
        final class func primitive(_ value: Bool) -> BoolValue {
            return BoolValue(value: value)
        }
        
        public func toString() -> String{
            return "<value at:\(id)>"
        }
    }
    
    public class PrimitiveValue : Value {
        final var primitiveType: PrimitiveTypeSymbol { type as! PrimitiveTypeSymbol }
        
        final var isNumeric: Bool { self.isInt || self.isDouble }
        
        final var isInt    : Bool { self is IntValue }
        final var isDouble : Bool { self is DoubleValue }
        final var isString : Bool { self is StringValue }
        final var isBool   : Bool { self is BoolValue }
        
        func asDouble() -> Double? { return nil }
    }
    
    public class IntValue : PrimitiveValue {
        final var value: Int
        
        override func asDouble() -> Double? {
            return Double(value)
        }

        init(value: Int) {
            self.value = value

            super.init()

            type = .intType
        }
        
        public override func toString() -> String {
            return "\(value)"
        }
    }

    public class DoubleValue : PrimitiveValue {
        final var value: Double
        
        override func asDouble() -> Double? {
            return value
        }

        init(value: Double) {
            self.value = value

            super.init()

            type = .doubleType
        }
        
        public override func toString() -> String {
            return "\(value)"
        }
    }
    
    public class StringValue : PrimitiveValue {
        final var value: String

        init(value: String) {
            self.value = value

            super.init()

            type = .stringType
        }
        
        public override func toString() -> String {
            return "\(value)"
        }
    }
    
    public class BoolValue : PrimitiveValue {
        final var value: Bool

        init(value: Bool) {
            self.value = value

            super.init()

            type = .boolType
        }
        
        public override func toString() -> String {
            return "\(value)"
        }
    }
}
