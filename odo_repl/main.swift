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
    
    do {
        let result = try inter.interpret(code: val)
        print(result)
    } catch let err as Odo.OdoException {
        print(err.description())
    }
//    let lexer = Odo.Lexer(text: val ?? "")
//    var currToken = try! lexer.getNextToken()
//
//    while currToken.type != .eof {
//        print(currToken.toString())
//        currToken = try! lexer.getNextToken()
//    }
    
}
