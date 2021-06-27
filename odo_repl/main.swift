//
//  main.swift
//  odo_repl
//
//  Created by Luis Gonzalez on 29/5/21.
//

import Foundation
import odo

// Multiline code snipped to run before repl
let initialCode = """
    func a() {
        writeln("hey!, this is a scripted function")
        # Works because by the time it's
        # first called, someVar has been declared
        writeln(someVar)
    }
    
    func b() {
        # Doesn't work because we never declare
        # this variable
        writeln(doesntExist)
    }
    
    var someVar = 200.1234
    
    a()
    b()
    """

let inter = Odo.Interpreter()
var running = true
var exitCode: Int32?

do {
    let _ = try inter.interpret(code: initialCode)
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
