//
//  main.swift
//  odo_repl
//
//  Created by Luis Gonzalez on 29/5/21.
//

import odo

let inter = Odo.Interpreter()

while true {
    print("> ", terminator: "")
    let val = readLine()!
    
    if val == "exit()" {
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
