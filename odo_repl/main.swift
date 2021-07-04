//
//  main.swift
//  odo_repl
//
//  Created by Luis Gonzalez on 29/5/21.
//

import Foundation
import odolib

// Multiline code snippet to run before repl
let initialCode = """
    module math {
        var e = 2.718281828459045235

        func exp(n: double): double {
            # Because of scoping, this uses
            # pow inside this module
            return pow(e, n)
        }
    
        func pow(x: double, n: double = 2): double {
            var result: double = 1

            forange : n {
                result = result * x
            }
            return result
        }
    }
    
    var a = 3
    var b = 5
    writeln(a, " to the ", b, " is: ", math::pow(a, b))
    
    writeln("e to the ", b, " is: ", math::exp(b))
    """

let inter = Odo.Interpreter()
var running = true
var exitCode: Int32?

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
