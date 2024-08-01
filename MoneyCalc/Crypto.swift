//
//  Crypto.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-11-06.
//

import Foundation

class TypeFinancial: TypeRecord {
    
    let suffix: String
    var mode: FormatMode = .fixMode
    var usd: Double
    var digits: Int    
    var minDigits: Int = 2

    
    init(_ suffix: String, usd: Double, digits: Int ) {
        self.suffix = suffix
        self.usd = usd
        self.digits = digits
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
        TypeCrypto("BTC" , usd: 66000.00, digits: 8 ),
        TypeCrypto("ETH" , usd:  5900.00, digits: 8 ),
        TypeCrypto("SOL" , usd:   244.00, digits: 8 ),
        TypeCrypto("ADA" , usd:     2.05, digits: 4 ),
        TypeCrypto("DOT" , usd:    53.00, digits: 4 ),
        TypeCrypto("LINK", usd:    34.00, digits: 4 )
    ]

    override init(_ suffix: String, usd: Double, digits: Int ) {
        super.init( suffix, usd: usd, digits: digits )
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
        TypeFiat("USD" ,  usd: 1.00, digits: 2 ),
        TypeFiat("CAD" ,  usd: 0.80, digits: 2 ),
        TypeFiat("EUR" ,  usd: 1.16, digits: 2 ),
        TypeFiat("GBP" ,  usd: 1.35, digits: 2 ),
        TypeFiat("AUD" ,  usd: 0.74, digits: 2 ),
        TypeFiat("JPY" ,  usd: 0.0088, digits: 2 )
    ]

    override init(_ suffix: String, usd: Double, digits: Int ) {
        super.init( suffix, usd: usd, digits: digits )
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
