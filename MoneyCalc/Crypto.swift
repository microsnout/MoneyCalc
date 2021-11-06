//
//  Crypto.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-11-06.
//

import Foundation

class TypeCrypto: TypeRecord {
    
    let suffix: String
    
    static let cryptoTable: [TypeCrypto] = [
        TypeCrypto("BTC"),
        TypeCrypto("ETH"),
        TypeCrypto("SOL"),
        TypeCrypto("ADA"),
        TypeCrypto("DOT"),
        TypeCrypto("XRP")
    ]

    init(_ suffix: String ) {
        self.suffix = suffix
    }
    
    static func getRecord(_ index: Int ) -> TypeCrypto {
        
        guard index >= 0 && index < TypeCrypto.cryptoTable.count else {
            return TypeCrypto("???")
        }
        
        return cryptoTable[index]
    }
}

extension CalculatorModel {
    
    func cryptoKeyPress(_ id: KeyID ) {
        let index = id - sk0
        
        guard index >= 0 && index < TypeCrypto.cryptoTable.count else {
            return
        }
        
//        let crypto = cryptoTable[index]
        
        if state.Xt.class == .untyped {
            undoStack.push(state)
            state.Xt = (.crypto, index)
        }
    }
}
