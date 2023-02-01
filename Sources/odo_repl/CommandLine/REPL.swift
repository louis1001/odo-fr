//
//  REPL.swift
//  
//
//  Created by Luis Gonzalez on 27/1/23.
//

import odolib
import LineNoise
import Foundation

func repl(interpreter: Odo.Interpreter = .init()) throws -> Never {
    var running = true
    var exitCode: Int32?
    
    interpreter.prepareStd()
    
    do {
        let _ = try interpreter.repl(code: INITIAL_CODE)
    } catch let err as Odo.OdoException {
        print(err.description())
    }
    
    interpreter.addVoidFunction("exit", takes: [.intOr(0)]) { args, _ in
        let arg = (args.first as! Odo.IntValue).asInt()
        exitCode = Int32(arg)
        
        running = false
    }
    
    let historyFile = "/tmp/odo_history.txt"
    let ln = LineNoise()
    try? ln.loadHistory(fromFile: historyFile)

    while running {
    //    print("> ", terminator: "")
        guard let val = try? ln.getLine(prompt: "> ") else {
            break
        }
        
        print("")
        ln.addHistory(val)
        
        do {
            let result = try interpreter.repl(code: val)
            if result !== Odo.Value.null {
                print(result)
            }
        } catch let err as Odo.OdoException {
            print(err.description())
        }

    }

    try? ln.saveHistory(toFile: "/tmp/history.txt")

    if let code = exitCode {
        exit(code)
    } else {
        exit(0)
    }
}

// Multiline code snippet to run before repl
private let INITIAL_CODE = """
module math_concepts {
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

    func describe(n: int) {
        const the_sign = get_sign(n)
        if the_sign == sign::zero {
            io::writeln(n, " is ", the_sign)
        } else {
            io::writeln(n, " is a ", get_sign(n), " number.")
        }
    }
}

const x = 10
const y = -10
const z = x + y

math_concepts::describe(x)
math_concepts::describe(z)
math_concepts::describe(y)

io::writeln("\n\nnested access:\n")

module a {
    enum b {
        c
    }

    func nested_access() {
        io::writeln("b::c -> ", b::c)
    }
}

a::nested_access()

io::writeln("\n\nfunction expression:\n")

# variable with single-expression function
var double_number = func(n: double) ~> n * 2

# constant with single-expression, ternary operator function
const relu = func(n: int) ~> n < 0 ? 0 : n

# constant with full-body function that returns
const simple_add = func(n: int) {
    const value = 20
    return n + value
}

# constant with full-body void function
const show_add = func(n: int) {
    const result = simple_add(n)
    io::writeln(n, " + ", 20, " = ", result)
}

io::writeln("expression: ", relu(20))
show_add(10)

# FIXME: Should be -> <int:int>
io::writeln("\ntypeof simple_add: ", typeof(simple_add))
"""
