//
//  Crypto.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-11-06.
//

import Foundation

class TypeFinancial: TypeRecord {
    
    let suffix: String
    var usd: Double
    
    init(_ suffix: String, _ usd: Double ) {
        self.suffix = suffix
        self.usd = usd
    }

    static func getRecord(_ tag: TypeTag ) -> TypeFinancial? {
        
        switch tag.class {
        case .crypto:
            return TypeCrypto.getRecord( tag.index )
            
        case .fiat:
            return TypeFiat.getRecord( tag.index )
            
        default:
            return nil
        }
    }
}

class TypeCrypto: TypeFinancial {
    
    static let cryptoTable: [TypeCrypto] = [
        TypeCrypto("BTC" , 66000.00 ),
        TypeCrypto("ETH" ,  5900.00 ),
        TypeCrypto("SOL" ,   244.00 ),
        TypeCrypto("ADA" ,     2.05 ),
        TypeCrypto("DOT" ,    53.00 ),
        TypeCrypto("LINK",    34.00 )
    ]

    override init(_ suffix: String, _ usd: Double ) {
        super.init( suffix, usd )
    }
    
    static func getRecord(_ index: Int ) -> TypeCrypto? {
        
        guard index >= 0 && index < TypeCrypto.cryptoTable.count else {
            return nil
        }
        
        return cryptoTable[index]
    }
}

class TypeFiat: TypeFinancial {
    
    static let fiatTable: [TypeFiat] = [
        TypeFiat("USD" ,  1.00 ),
        TypeFiat("CAD" ,  0.80 ),
        TypeFiat("EUR" ,  1.16 ),
        TypeFiat("GBP" ,  1.35 ),
        TypeFiat("AUD" ,  0.74 ),
        TypeFiat("JPY" ,  0.0088 )
    ]

    override init(_ suffix: String, _ usd: Double ) {
        super.init( suffix, usd )
    }
    
    static func getRecord(_ index: Int ) -> TypeFiat? {
        
        guard index >= 0 && index < TypeFiat.fiatTable.count else {
            return nil
        }
        
        return fiatTable[index]
    }
}

extension CalculatorModel {
    
    func financialKeyPress(_ s1Tag: TypeTag ) {

        if let s1Type = TypeFinancial.getRecord(s1Tag) {
        
            if state.Xt.class == .untyped {
                // Value doesn't change, set new tag
                undoStack.push(state)
                state.Xt = s1Tag
            }
            else {
                if let s0Type = TypeFinancial.getRecord( state.Xt ) {
                    // Convert value and set type
                    undoStack.push(state)
                    state.X = state.X * s0Type.usd / s1Type.usd
                    state.Xt = s1Tag
                }
            }
        }
    }
}
