//
//  CalculatorView.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import SwiftUI

let key0 = 0, key1 = 1, key2 = 2, key3 = 3, key4 = 4, key5 = 5, key6 = 6, key7 = 7, key8 = 8, key9 = 9

let plus = 10, minus = 11, times = 12, divide = 13

let dot = 20, enter = 21, clear = 22, equal = 23, back = 24, blank = 25

let sk0 = 30, sk1 = 31, sk2 = 32, sk3 = 33, sk4 = 34, sk5 = 35, sk6 = 36, sk7 = 37, sk8 = 38, sk9 = 39

let padDigits = 0, padOp = 1, padEnter = 2, padClear = 3

let rowCrypto = 10, rowFiat = 11


struct CalculatorView: View {
    @StateObject private var model = CalculatorModel()
    
    let keySpec = KeySpec(
        width: 40, height: 40,
        radius: 10, spacing: 10,
        buttonColor: Color("KeyColor"), textColor: Color("KeyText"))
    
    let numPad = PadSpec(
        id: padDigits,
        rows: 4, cols: 3,
        keys: [ Key(key7, "7"), Key(key8, "8"), Key(key9, "9"),
                Key(key4, "4"), Key(key5, "5"), Key(key6, "6"),
                Key(key1, "1"), Key(key2, "2"), Key(key3, "3"),
                Key(key0, "0"), Key(dot, ".")
              ])
    
    let opPad = PadSpec(
        id: padOp,
        rows: 4, cols: 1,
        keys: [ Key(divide, "÷"),
                Key(times, "×"),
                Key(minus, "−"),
                Key(plus,  "+")
              ])
    
    let enterPad = PadSpec(
        id: padEnter,
        rows: 1, cols: 3,
        keys: [ Key(enter, "Enter", size: 2, fontSize: 15),
                Key(back, "🔙")
              ])
    
    let clearPad = PadSpec(
        id: padClear,
        rows: 1, cols: 1,
        keys: [ Key(clear, "CLx", fontSize: 15)
              ])
    
    // **************************
    
    let skSpec = KeySpec(
        width: 50, height: 30,
        radius: 10, spacing: 10,
        buttonColor: Color("KeyColor"), textColor: Color("KeyText"))
    
    let cryptoRowSpec = RowSpec (
        id: rowCrypto,
        keys: [ SoftKey(sk0, "BTC"),
                SoftKey(sk1, "ETH"),
                SoftKey(sk2, "SOL"),
                SoftKey(sk3, "ADA"),
                SoftKey(sk4, "DOT"),
                SoftKey(sk5, "XRP")
              ],
        fontSize: 15.0,
        caption: "Crypto"
    )

    let fiatRowSpec = RowSpec (
        id: rowFiat,
        keys: [ SoftKey(sk0, "USD"),
                SoftKey(sk1, "CAD"),
                SoftKey(sk2, "EUR"),
                SoftKey(sk3, "GBP"),
                SoftKey(sk4, "AUD"),
                SoftKey(sk5, "JPY")
              ],
        fontSize: 15.0,
        caption: "Fiat"
    )

    // **************************

    var body: some View {
        ZStack(alignment: .center) {
            Rectangle()
                .fill(Color("Background"))
                .edgesIgnoringSafeArea( [.bottom] )
            
            ZStack
            {
//                Rectangle()
//                    .stroke( Color.gray )
//                    .foregroundColor( Color.clear)
                 
                VStack(alignment: .leading) {
                    Spacer()
                    Display( buffer: model.buffer )
                    SoftKeyRow( keySpec: skSpec, rowSpec: cryptoRowSpec, keyPressHandler: model )
                        .padding( .vertical, 5 )
                    SoftKeyRow( keySpec: skSpec, rowSpec: fiatRowSpec, keyPressHandler: model )
                        .padding( .vertical, 5 )
                    VStack( alignment: .leading) {
                        HStack {
                            Keypad( keySpec: keySpec, padSpec: numPad, keyPressHandler: model )
                            Keypad( keySpec: keySpec, padSpec: opPad, keyPressHandler: model )
                        }
                        HStack {
                            Keypad( keySpec: keySpec, padSpec: enterPad, keyPressHandler: model)
                            Keypad( keySpec: keySpec, padSpec: clearPad, keyPressHandler: model)
                        }
                    }.alignmentGuide(.leading, computeValue: {_ in -30})
                    Spacer()
                }
            }.padding(30)
        }

            
    }
}

struct CalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        CalculatorView()
            .padding()
    }
}

