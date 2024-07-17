//
//  KeypadView.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import SwiftUI

typealias KeyID = Int
typealias PadID = Int
typealias RowID = Int

typealias  KeyEvent = ( pad: PadID, key: KeyID )

protocol KeyPressHandler {
    func keyPress(_ event: KeyEvent )
}

struct KeySpec {
    var width: Double
    var height: Double
    var radius: Double
    var spacing: Double
    var buttonColor: Color
    var textColor: Color
}

struct Key: Identifiable {
    var id: KeyID
    var ch: String
    var size: Int
    var fontSize:Double?
    
    init(_ id: KeyID, _ ch: String, size: Int = 1, fontSize: Double? = nil ) {
        self.id = id
        self.ch = ch
        self.size = size
        self.fontSize = fontSize
    }
}

struct PadSpec {
    var id: PadID
    var rows: Int
    var cols: Int
    var keys: [Key]
    var fontSize = 20.0
}

struct Keypad: View {
    
    var keySpec: KeySpec
    var padSpec: PadSpec
    
    var keyPressHandler:  KeyPressHandler
    
    private var columns: [GridItem] {
        Array(repeating: .init(.fixed(keySpec.width)), count: padSpec.cols)
    }
    
    var body: some View {
        LazyVGrid(
            columns: columns,
            alignment: .leading,
            spacing: keySpec.spacing
        ) {
            ForEach(padSpec.keys) { key in
                Button( action: {
                    keyPressHandler.keyPress( (padSpec.id, key.id) )
                })
                {
                    Rectangle()
                        .foregroundColor(keySpec.buttonColor)
                        .frame( width: key.size == 2 ?
                                        keySpec.width * 2.0 + keySpec.spacing :
                                        keySpec.width,
                               height: keySpec.height,
                               alignment: .center)
                        .cornerRadius(keySpec.radius)
                        .shadow(radius: keySpec.radius)
                        .overlay(
                            Text("\(key.ch)")
                                .font(.system(size: key.fontSize == nil ? padSpec.fontSize : key.fontSize! ))
                                .background( keySpec.buttonColor)
                                .foregroundColor( keySpec.textColor),
                            alignment: .center)
                }
                
                if key.size == 2 { Color.clear }
             }
        }
        .frame( width: (keySpec.width + keySpec.spacing) * Double(padSpec.cols))
        .padding( .vertical, 5 )
    }
}

// ********************************************

struct SoftKey: Identifiable {
    var id: KeyID
    var ch: String
    
    init(_ id: KeyID, _ ch: String ) {
        self.id = id
        self.ch = ch
    }
}

struct RowSpec {
    var id: RowID
    var keys: [SoftKey]
    var fontSize: Double
    var caption: String
}

struct SoftKeyRow: View {
    
    var keySpec: KeySpec
    var rowSpec: RowSpec
    
    var keyPressHandler:  KeyPressHandler
    
    var body: some View {
        HStack {
            ForEach(rowSpec.keys, id: \.id) { key in
                Button( action: {
                    keyPressHandler.keyPress( (rowSpec.id, key.id) )
                })
                {
                    Spacer()
                    Rectangle()
                        .foregroundColor(keySpec.buttonColor)
                        .frame( width: keySpec.width,
                               height: keySpec.height,
                               alignment: .center)
                        .cornerRadius(keySpec.radius)
                        .overlay(
                            Text("\(key.ch)")
                                .font(.system(size: rowSpec.fontSize ))
                                .background( keySpec.buttonColor)
                                .foregroundColor( keySpec.textColor),
                            alignment: .center)
                    Spacer()
                }
             }
        }
        .padding( .vertical, 12 )
        .overlay(
            Rectangle()
                .stroke( Color("Frame") )
                .foregroundColor( Color.clear )
                .overlay(
                    Text( rowSpec.caption )
                        .padding( .horizontal, 5 )
                        .background( Color("Background") )
                        .foregroundColor( Color("Frame") )
                        .font(.system(size: 10.0 ))
                        .alignmentGuide(.leading, computeValue: {_ in -10})
                        .alignmentGuide(.top, computeValue: {_ in 7})
                        ,
                   alignment: .topLeading
                )
        )
    }
}


