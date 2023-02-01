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
io::writeln("Welcome!")
"""
