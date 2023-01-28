//
//  STD.swift
//  
//
//  Created by Luis Gonzalez on 27/1/23.
//

import odolib
import Foundation

// MARK: - STDLib definition

func prepareStd(on interpreter: Odo.Interpreter) {
    
    // MARK: Global
    interpreter.addFunction("typeof", takes: .some(1)) { args, _ in
        let first = args.first!.type
        return .literal(first?.name ?? "<no type>")
    }
    
    // MARK: Math
    let mathModule = interpreter.addModule("math")
    mathModule.add("e", value: M_E)
    mathModule.add("pi", value: .pi)

    mathModule.addFunction("pow", takes: [.double, .doubleOr(2)], returns: .doubleType) { args, _ in
        let x = (args[0] as! Odo.PrimitiveValue).asDouble()!
        let n = (args[1] as! Odo.PrimitiveValue).asDouble()!
        
        return .literal(pow(x, n))
    }
    
    mathModule.addFunction("exp", takes: [.double], returns: .doubleType) { args, _ in
        let arg1 = (args.first! as! Odo.PrimitiveValue).asDouble()!
        return .literal(pow(M_E, arg1))
    }
    
    // MARK: IO
    let io = interpreter.addModule("io")
    // TODO: Maybe remove the one from the global scope?
    // Adds some kind of "puts" that only takes a string
    // Just to make sure the language could be usable without
    //  a standard library
    
    func write(_ args: [Odo.Value], _ inter: Odo.Interpreter) -> Void {
        for arg in args {
            print(arg, terminator: "")
        }
    }
    
    io.addVoidFunction("write", takes: .whatever, body: write)
    io.addVoidFunction("writeln", takes: .whatever) {
        write($0, $1)
        print()
    }
    
    io.addVoidFunction("clear") {
        print("\u{001B}[2J")
    }
}
