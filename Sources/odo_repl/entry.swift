//
//  entry.swift
//  odo_repl
//
//  Created by Luis Gonzalez on 29/5/21.
//

import odolib
import ArgumentParser

@main
struct OdoEntry: ParsableCommand {
    static var configuration: CommandConfiguration = CommandConfiguration(commandName: "odo")
    
    @Argument(help: "A file to run")
    var file: String? = nil
    
    @Flag(name: .shortAndLong, help: "Interactive mode. To run a repl after running the file")
    var interactive = false
    
    @Flag(name: .shortAndLong, help: "Prints version number")
    var version = false
    
    @Flag(name: .shortAndLong, help: "Prints version number")
    var longVersion = false
    
    mutating func run() throws {
        if version || longVersion {
            printVersion(long: longVersion)
        } else if let file {
            try execute(file: file, interactive: interactive)
        } else {
            try repl()
        }
    }
}
