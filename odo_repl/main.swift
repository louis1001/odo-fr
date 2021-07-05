//
//  main.swift
//  odo_repl
//
//  Created by Luis Gonzalez on 29/5/21.
//

import Foundation
import odolib

func prepareStd(on interpreter: Odo.Interpreter) {
    let mathModule = interpreter.addModule("math")
    mathModule.add("e", value: M_E)
    mathModule.add("pi", value: .pi)
    
    // TODO: Simplify this api
    //       maybe define the args as (.intType, 2),
    //       so that the default value indicates an optional
    
    // IDEA:
    //      An enum with the kinds of arguments:
    //      .type(TypeSymbol) <- required, just the type passed
    //      .int <- required, int
    //      .intOr(Int) <- optional
    mathModule.add("pow", takes: .someOrLess(2)) { args, _ in
        let arg1 = (args.first! as! Odo.PrimitiveValue).asDouble()!
        let power: Double
        
        if args.count > 1 {
            power = (args[1] as! Odo.PrimitiveValue).asDouble()!
        } else {
            power = 2
        }

        return .literal(pow(arg1, power))
    } validation: { args, semAn in
        try semAn.validate(arg: args.first!, type: .doubleType)

        if args.count > 1 {
            try semAn.validate(arg: args[1], type: .doubleType)
        }
        return .doubleType
    }
    
    mathModule.add("exp", takes: .some(1)) { args, _ in
        let arg1 = (args.first! as! Odo.PrimitiveValue).asDouble()!
        return .literal(pow(M_E, arg1))
    } validation: { args, semAn in
        try semAn.validate(arg: args.first!, type: .doubleType)
        return .doubleType
    }
    
    let io = interpreter.addModule("io")
    
    // TODO: Maybe remove the one from the global scope?
    // Adds some kind of "puts" that only takes a string
    // Just to make sure the language could be usable without
    //  a standard library
    io.add("writeln", takes: .any) { args, _ in
        for arg in args {
            print(arg, terminator: "")
        }
        print()
        return .null
    }
}

// Multiline code snippet to run before repl
let initialCode = """
    var a = 3
    var b = 5
    writeln(a, " to the ", b, " is: ", math::pow(a, b))
    
    writeln("e to the ", b, " is: ", math::exp(b))
    """

let inter = Odo.Interpreter()
var running = true
var exitCode: Int32?

prepareStd(on: inter)

do {
    let _ = try inter.repl(code: initialCode)
} catch let err as Odo.OdoException {
    print(err.description())
}

inter.addNativeFunction("exit", takes: .someOrLess(1)) {args, _ in
    if let arg = (args.first as? Odo.PrimitiveValue)?.asDouble() {
        exitCode = Int32(arg)
    }
    running = false
    return .null
} validation: { args, semAn in
    if !args.isEmpty {
        try semAn.validate(arg: args.first!, type: .intType)
    }
    return nil
}

inter.addNativeFunction("clear") { _, _ in
    print("\u{001B}[2J")
    return .null
}

while running {
    print("> ", terminator: "")
    guard let val = readLine() else {
        break
    }
    
    do {
        let result = try inter.repl(code: val)
        if result !== Odo.Value.null {
            print(result)
        }
    } catch let err as Odo.OdoException {
        print(err.description())
    }

}

if let code = exitCode {
    exit(code)
}
