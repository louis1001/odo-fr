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
    writeln("1 > 4 = ", 1 > 4)
    writeln("1 < 4 = ", 1 < 4)
    writeln("1 <= 4 = ", 1 <= 4)
    writeln("1 >= 4 = ", 1 >= 4)
    
    var i = 0
    while i < 10 {
        writeln("i is ", i, " which is less than 10")
    
        i = i + 1
    }
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
