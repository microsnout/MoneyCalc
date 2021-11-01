//
//  CalculatorView.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import SwiftUI

struct CalculatorView: View {
    @StateObject private var model = CalculatorModel()
    
    let keySpec = KeySpec(
        width: 40, height: 40,
        radius: 10, spacing: 10,
        buttonColor: Color("KeyColor"), textColor: Color("KeyText"))
    
    let numPad = PadSpec(
        rows: 4, cols: 3,
        keys: [ Key(.key7, "7"), Key(.key8, "8"), Key(.key9, "9"),
                Key(.key4, "4"), Key(.key5, "5"), Key(.key6, "6"),
                Key(.key1, "1"), Key(.key2, "2"), Key(.key3, "3"),
                Key(.key0, "0"), Key(.dot, ".")
              ])
    
    let opPad = PadSpec(
        rows: 4, cols: 1,
        keys: [ Key(.divide, "÷"),
                Key(.times, "×"),
                Key(.minus, "−"),
                Key(.plus,  "+")
              ])
    
    let enterPad = PadSpec(
        rows: 1, cols: 3,
        keys: [ Key(.enter, "Enter", size: 2, fontSize: 15),
                Key(.back, "🔙")
              ])
    
    let clearPad = PadSpec(
        rows: 1, cols: 1,
        keys: [ Key(.clear, "CLx", fontSize: 15)
              ])

    var body: some View {
        ZStack(alignment: .center) {
            Rectangle()
                .fill(Color("Background"))
                .edgesIgnoringSafeArea( [.bottom] )
            
            ZStack(alignment: .center)
            {
//                Rectangle()
//                    .stroke( Color.gray )
//                    .foregroundColor( Color.clear)
                 
                VStack(alignment: .leading) {
                    Spacer()
                    Display( buffer: model.buffer )
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

