//
//  CalculatorView.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import SwiftUI

struct RoundedCorner: Shape {

    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}


struct CalculatorView: View {
    @StateObject  var model = CalculatorModel()
    
    let keySpec = KeySpec(
        width: 50, height: 40,
        radius: 10, spacing: 10,
        buttonColor: Color("KeyColor"), textColor: Color("KeyText"))
    
    let numPad = PadSpec(
        pc: .padDigits,
        rows: 4, cols: 3,
        keys: [ Key(.key7, "7"), Key(.key8, "8"), Key(.key9, "9"),
                Key(.key4, "4"), Key(.key5, "5"), Key(.key6, "6"),
                Key(.key1, "1"), Key(.key2, "2"), Key(.key3, "3"),
                Key(.key0, "0"), Key(.dot, "."),  Key(.sign, "+/-", fontSize: 15)
              ])
    
    let opPad = PadSpec(
        pc: .padOp,
        rows: 4, cols: 3,
        keys: [ Key(.divide, "÷"), Key(.fixL, ".00\u{2190}", fontSize: 12), Key(.y2x, image: .yx),
                Key(.times, "×"),  Key(.fixR, ".00\u{2192}", fontSize: 12), Key(.inv, image: .onex),
                Key(.minus, "−"),  Key(.xy, "X\u{21c6}Y", fontSize: 12),    Key(.x2, image: .x2),
                Key(.plus,  "+"),  Key(.roll, "R\u{2193}", fontSize: 12),   Key(.sqrt, image: .rx)
              ])
    
    let enterPad = PadSpec(
        pc: .padEnter,
        rows: 1, cols: 3,
        keys: [ Key(.enter, "Enter", size: 2, fontSize: 15)
              ])
    
    let clearPad = PadSpec(
        pc: .padClear,
        rows: 1, cols: 3,
        keys: [ Key(.back, "BACK/UNDO", size: 2, fontSize: 12), Key(.clear, "CLx", fontSize: 12)
              ])
    
    // **************************
    
    let skSpec = KeySpec(
        width: 50, height: 30,
        radius: 10, spacing: 10,
        buttonColor: Color("KeyColor"), textColor: Color("KeyText"))
    
    let fiatRowSpec = RowSpec (
        pc: .padFiat,
        keys: [ SoftKey(.sk0, "USD"),
                SoftKey(.sk1, "CAD"),
                SoftKey(.sk2, "EUR"),
                SoftKey(.sk3, "GBP"),
                SoftKey(.sk4, "AUD"),
                SoftKey(.sk5, "JPY")
              ],
        fontSize: 15.0,
        caption: "Currency"
    )

    // **************************
    
    let swipeLeadingOpTable: [(KeyCode, String, Color)] = [
        ( .rcl,    "RCL", .mint ),
        ( .sto,    "STO", .indigo ),
        ( .mPlus,  "M+",  .cyan  ),
        ( .mMinus, "M-",  .green )
    ]

    var body: some View {
        ZStack(alignment: .center) {
            Rectangle()
                .fill(Color("Display"))
                .edgesIgnoringSafeArea( .all )
            
            VStack
            {
                MemoryDisplay( model: model, leadingOps: swipeLeadingOpTable )
                ZStack {
                    VStack(alignment: .center) {
                        Display( model: model )
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
                        }.alignmentGuide(.leading, computeValue: {_ in 0})
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                    .background( Color("Background"))
                }
            }
        }
    }
}

struct CalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        CalculatorView()
            .padding()
    }
}

