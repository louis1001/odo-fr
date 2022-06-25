
extension Odo {

class Scope {
    typealias SymbolId = Int
    var id: Int
    var symbols: [SymbolId] = []
    
    var parentId: Int?
    
    init(id: Int) {
        self.id = id
    }
    
    func add(_ symbol: SymbolId) {
        symbols.append(symbol)
    }
}

}