//
//  Value.swift
//  odo
//
//  Created by Luis Gonzalez on 29/5/21.
//

import Foundation

extension Odo {
    public class Value: Identifiable, CustomStringConvertible {
        public let id = UUID()
        final var type: TypeSymbol!
        var isPrimitive: Bool { false }

        public static let null: PrimitiveValue = NullValue()
        
        final class func primitive(_ value: Int) -> IntValue {
            return IntValue(value: value)
        }
        
        final class func primitive(_ value: Double) -> DoubleValue {
            return DoubleValue(value: value)
        }
        
        final class func primitive(_ value: String) -> TextValue {
            return TextValue(value: value)
        }
        
        final class func primitive(_ value: Bool) -> BoolValue {
            return BoolValue(value: value)
        }
        
        public var description: String {
            "<value at:\(id)>"
        }

        public func toText() -> String {
            return description
        }
    }
    
    public class PrimitiveValue : Value {
        final var primitiveType: PrimitiveTypeSymbol { type as! PrimitiveTypeSymbol }
        
        final var isNumeric: Bool { self.isInt || self.isDouble }
        
        final var isInt    : Bool { self is IntValue }
        final var isDouble : Bool { self is DoubleValue }
        final var isText : Bool { self is TextValue }
        final var isBool   : Bool { self is BoolValue }
        
        func asDouble() -> Double? { return nil }
    }
    
    fileprivate class NullValue : PrimitiveValue {
        public override var description: String {
            "null"
        }
        
        override init() {
            super.init()
            type = .nullType
        }
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
        
        public override var description: String {
            "\(value)"
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
        
        public override var description: String {
            "\(value)"
        }
    }
    
    public class TextValue : PrimitiveValue {
        final var value: String

        init(value: String) {
            self.value = value

            super.init()

            type = .textType
        }
        
        public override var description: String {
            "\(value)"
        }
    }
    
    public class BoolValue : PrimitiveValue {
        final var value: Bool

        init(value: Bool) {
            self.value = value

            super.init()

            type = .boolType
        }
        
        public override var description: String {
            "\(value)"
        }
    }
}
