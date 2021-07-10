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
        public final var type: TypeSymbol!
        var isPrimitive: Bool { false }
        
        var address: UnsafeMutableRawPointer {
            Unmanaged.passUnretained(self).toOpaque()
        }

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
        
        public var className: String { "value" }
        
        public var description: String {
            "<\(className) at:\(address)>"
        }

        public func toText() -> String {
            return description
        }
        
        public static func literal(_ value: Int) -> IntValue {
            return IntValue(value: value)
        }
        
        public static func literal(_ value: Double) -> DoubleValue {
            return DoubleValue(value: value)
        }
        
        public static func literal(_ value: Bool) -> BoolValue {
            return BoolValue(value: value)
        }
        
        public static func literal(_ value: String) -> TextValue {
            return TextValue(value: value)
        }
    }
    
    public class PrimitiveValue : Value {
        final var primitiveType: PrimitiveTypeSymbol { type as! PrimitiveTypeSymbol }
        
        final var isNumeric: Bool { self.isInt || self.isDouble }
        
        final var isInt    : Bool { self is IntValue }
        final var isDouble : Bool { self is DoubleValue }
        final var isText : Bool { self is TextValue }
        final var isBool   : Bool { self is BoolValue }
        
        public func asDouble() -> Double? { return nil }
        public func asBool() -> Bool? { return nil }
        public func asText() -> String? { return nil }
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
        
        public override func asDouble() -> Double? {
            return Double(value)
        }
        
        public final func asInt() -> Int { value }

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
        
        public override func asDouble() -> Double? {
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
        
        public override final func asText() -> String? {
            return value
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
        
        public override final func asBool() -> Bool? {
            return value
        }
        
        public override var description: String {
            "\(value)"
        }
    }
    
    public class FunctionValue : Value {
        fileprivate override init() {
            super.init()
        }
        
        public override var className: String { "function" }
    }
    
    public class NativeFunctionValue : FunctionValue {
        public typealias NativeFunctionCallback = ([Value], Interpreter) throws -> Value

        var functionBody: NativeFunctionCallback = { _, _ in
            .null
        }
        
        var optionalArgs: [Value?]? = nil
        
        init(type: NativeFunctionTypeSymbol = .shared, body: NativeFunctionCallback? = nil) {
            super.init()
            self.type = type
            
            if let body = body {
                functionBody = body
            }
        }
        
        public override var className: String { "nativeFunction" }
    }
    
    public class ScriptedFunctionValue : FunctionValue {
        let parameters: [Node]
        let body: Node
        let parentScope: SymbolTable
        let name: String?
        
        init(type: ScriptedFunctionTypeSymbol, parameters: [Node], body: Node, parentScope: SymbolTable, name: String? = nil) {
            self.parameters = parameters
            self.body = body
            self.parentScope = parentScope
            self.name = name
            
            super.init()

            self.type = type
        }
    }
    
    public class ModuleValue : Value {
        let scope: SymbolTable
        
        public override var className: String { "module" }
        
        init(scope: SymbolTable) {
            self.scope = scope
        }
    }
    
    public class NativeModule: ModuleValue {
        
        var analyzer: SemanticAnalyzer
        
        init(name: String, inter: Interpreter) {
            analyzer = inter.semAn
            super.init(scope: SymbolTable(name, parent: inter.globalTable))
        }
        
        public func add(_ name: String, value: Int, constant: Bool = true) {
            scope.addSymbol(
                VarSymbol(
                    name: name,
                    type: .intType,
                    value: IntValue(value: value),
                    isConstant: constant
                )
            )
        }
        
        public func add(_ name: String, value: Double, constant: Bool = true) {
            scope.addSymbol(
                VarSymbol(
                    name: name,
                    type: .doubleType,
                    value: DoubleValue(value: value),
                    isConstant: constant
                )
            )
        }
        
        public func add(_ name: String, value: String, constant: Bool = true) {
            scope.addSymbol(
                VarSymbol(
                    name: name,
                    type: .textType,
                    value: TextValue(value: value),
                    isConstant: constant
                )
            )
        }
        
        public func add(_ name: String, value: Bool, constant: Bool = true) {
            scope.addSymbol(
                VarSymbol(
                    name: name,
                    type: .boolType,
                    value: BoolValue(value: value),
                    isConstant: constant
                )
            )
        }
        
        public func addFunction(
            _ name: String,
            takes args: NativeFunctionSymbol.ArgType = .nothing,
            body: @escaping ([Value], Interpreter) throws -> Value,
            validation: (([Node], SemanticAnalyzer) throws -> TypeSymbol?)? = nil) {
            
            let functionSymbol = NativeFunctionSymbol(name: name, takes: args, validation: validation)
            scope.addSymbol(functionSymbol)
            
            let functionValue = NativeFunctionValue(body: body)
            functionSymbol.body = functionValue
        }
        
        public func addVoidFunction(
            _ name: String,
            takes args: NativeFunctionSymbol.ArgType = .nothing,
            body: @escaping ([Value], Interpreter) throws -> Void,
            validation: (([Node], SemanticAnalyzer) throws -> Void)? = nil) {
            
            addFunction(
                name,
                takes: args,
                body: {val, inter -> Value in
                    try body(val, inter)
                    return .null
                },
                validation: validation == nil
                    ? nil
                    : { try validation!($0, $1); return nil} )
        }
        
        public func addFunction(
            _ name: String,
            takes: [NativeFunctionSymbol.ArgumentDescription] = [],
            returns: TypeSymbol?,
            body: @escaping ([Value], Interpreter) throws -> Value
        ) {
            let args = takes.map { $0.get() }
            let functionType = ScriptedFunctionTypeSymbol(ret: returns, args: args)
            let functionSymbol = NativeFunctionSymbol(name: name, validation: nil)
            functionSymbol.type = functionType
            
            scope.addSymbol(functionSymbol)
            let _ = analyzer.addFunctionSemanticContext(for: functionType, name: functionType.name, params: args)
            
            let functionValue = NativeFunctionValue(body: body)
            functionValue.optionalArgs = takes.map { $0.getValue() }
            functionSymbol.body = functionValue
        }
        
        public func addVoidFunction(
            _ name: String,
            takes: [NativeFunctionSymbol.ArgumentDescription] = [],
            body: @escaping ([Value], Interpreter) throws -> Void
        ) {
            addFunction(name, takes: takes, returns: nil){
                try body($0, $1)
                return .null
            }
        }
        
        public func addVoidFunction(
            _ name: String,
            body: @escaping(() throws -> Void)
        ) {
            addVoidFunction(name, body: { _, _ in try body() })
        }
        
    }
}
