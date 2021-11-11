//
//  CalculatorView.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import SwiftUI

let key0 = 0, key1 = 1, key2 = 2, key3 = 3, key4 = 4, key5 = 5, key6 = 6, key7 = 7, key8 = 8, key9 = 9

let plus = 10, minus = 11, times = 12, divide = 13

let dot = 20, enter = 21, clear = 22, equal = 23, back = 24, sign = 25

let fixL = 30, fixR = 31, roll = 32, xy = 33, percent = 34, lastx = 35

let sk0 = 50, sk1 = 51, sk2 = 52, sk3 = 53, sk4 = 54, sk5 = 55, sk6 = 56, sk7 = 57, sk8 = 58, sk9 = 59

let padDigits = 0, padOp = 1, padEnter = 2, padClear = 3

let rowCrypto = 10, rowFiat = 11, rowStock = 12


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
                Key(key0, "0"), Key(dot, "."),  Key(sign, "+/-", fontSize: 15)
              ])
    
    let opPad = PadSpec(
        id: padOp,
        rows: 4, cols: 2,
        keys: [ Key(divide, "÷"), Key(fixL, ".00\u{2190}", fontSize: 12),
                Key(times, "×"),  Key(fixR, ".00\u{2192}", fontSize: 12),
                Key(minus, "−"),  Key(xy, "X\u{21c6}Y", fontSize: 12),
                Key(plus,  "+"),  Key(roll, "R\u{2193}", fontSize: 12)
              ])
    
    let enterPad = PadSpec(
        id: padEnter,
        rows: 1, cols: 3,
        keys: [ Key(enter, "Enter", size: 2, fontSize: 15),
                Key(back, "BACK", fontSize: 10)
              ])
    
    let clearPad = PadSpec(
        id: padClear,
        rows: 1, cols: 2,
        keys: [ Key(clear, "CLx", fontSize: 12), Key(lastx, "LASTx", fontSize: 10)
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
                SoftKey(sk5, "LINK")
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

    let stockRowSpec = RowSpec (
        id: rowStock,
        keys: [ SoftKey(sk0, "SU"),
                SoftKey(sk1, "T"),
                SoftKey(sk2, "APPL"),
                SoftKey(sk3, "ENB"),
                SoftKey(sk4, "BCE"),
                SoftKey(sk5, "BNS")
              ],
        fontSize: 15.0,
        caption: "Stock"
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
                    SoftKeyRow( keySpec: skSpec, rowSpec: stockRowSpec, keyPressHandler: model )
                        .padding( .vertical, 5 )
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

