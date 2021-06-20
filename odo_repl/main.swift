//
//  main.swift
//  odo_repl
//
//  Created by Luis Gonzalez on 29/5/21.
//

import odo

let inter = Odo.Interpreter()
var running = true

inter.addNativeFunction("exit") {_, _ in
    running = false
    return .null
}
validation: { args, _ in
    guard args.isEmpty else {
        return .failure(.RuntimeError(message: "Function exit takes no arguments"))
    }
    return .success(nil)
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
