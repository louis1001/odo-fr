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
    func testInt(val: int, fn: <int:bool>): bool {
        return fn(val)
    }
    
    func isPositive(n: int): bool {
        return n >= 0
    }
    
    func earlyReturn() {
        forange x: 50 {
            writeln(x)
            if x == 5 {
                return
                writeln("Should not run")
            }
            writeln("Should not run after 5")
        }
        writeln("Should not run")
    }

    # Next: Prefix operators
    var value = 0-2
    writeln("Is `", value, "` positive? ", testInt(value, isPositive))
    value = 35
    writeln("Is `", value, "` positive? ", testInt(value, isPositive))
    
    writeln("\n\nTesting early return\n")
    earlyReturn()
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
