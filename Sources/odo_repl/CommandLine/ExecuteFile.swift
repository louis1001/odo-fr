//
//  ExecuteFile.swift
//  
//
//  Created by Luis Gonzalez on 27/1/23.
//

import Foundation
import odolib

func execute(file: String, interactive: Bool) throws {
    // Read code
    let contents = try String(contentsOfFile: file)
    
    // Execute file
    let interpreter = Odo.Interpreter()
    prepareStd(on: interpreter)
    
    let _ = try interpreter.interpret(code: contents)
    
    if interactive {
        // repl with the file's contents on scope
        try repl(interpreter: interpreter)
    }
}
