//
//  main.swift
//  odo_repl
//
//  Created by Luis Gonzalez on 29/5/21.
//

import Foundation
import odolib

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

// Multiline code snippet to run before repl
let initialCode = """
    enum sign {
        positive
        zero
        negative
    }
    
    func get_sign(n: double): sign {
        if n < 0 {
            return sign::negative
        } else if n > 0 {
            return sign::positive
        } else {
            return sign::zero
        }
    }
    
    const x = 10
    const y = -10
    const z = x + y
    
    func describe(n: int) {
        const the_sign = get_sign(n)
        if the_sign == sign::zero {
            io::writeln(n, " is ", the_sign)
        } else {
            io::writeln(n, " is a ", get_sign(n), " number.")
        }
    }
    
    describe(x)
    describe(z)
    describe(y)
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

inter.addVoidFunction("exit", takes: [.intOr(0)]) { args, _ in
    let arg = (args.first as! Odo.IntValue).asInt()
    exitCode = Int32(arg)
    
    running = false
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
