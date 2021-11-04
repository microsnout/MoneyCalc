//
//  KeypadView.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import SwiftUI

protocol KeyPressHandler {
    func keyPress( id: KeyID )
}

struct KeySpec {
    var width: Double
    var height: Double
    var radius: Double
    var spacing: Double
    var buttonColor: Color
    var textColor: Color
}

public enum KeyID: Int {
    case key0 = 0, key1, key2, key3, key4, key5, key6, key7, key8, key9
    case plus, minus, times, divide
    case dot, enter, clear, equal, back, blank
    case sk0, sk1, sk2, sk3, sk4, sk5, sk6, sk7, sk8, sk9
}

struct Key: Identifiable {
    let id: KeyID
    let ch: String
    let size: Int
    let fontSize:Double?
    
    init(_ id: KeyID, _ ch: String, size: Int = 1, fontSize: Double? = nil ) {
        self.id = id
        self.ch = ch
        self.size = size
        self.fontSize = fontSize
    }
}

struct PadSpec {
    let rows: Int
    let cols: Int
    let keys: [Key]
    let fontSize = 20.0
}

struct Keypad: View {
    
    let keySpec: KeySpec
    let padSpec: PadSpec
    
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
            ForEach(padSpec.keys, id: \.id) { key in
                Button( action: {
                    keyPressHandler.keyPress( id: key.id )
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
    let id: KeyID
    let ch: String
    
    init(_ id: KeyID, _ ch: String ) {
        self.id = id
        self.ch = ch
    }
}

struct RowSpec {
    let keys: [SoftKey]
    let fontSize: Double
    let caption: String
}

struct SoftKeyRow: View {
    
    let keySpec: KeySpec
    let rowSpec: RowSpec
    
    var keyPressHandler:  KeyPressHandler
    
    var body: some View {
        HStack {
            ForEach(rowSpec.keys, id: \.id) { key in
                Button( action: {
                    keyPressHandler.keyPress( id: key.id )
                })
                {
                    Spacer()
                    Rectangle()
                        .foregroundColor(keySpec.buttonColor)
                        .frame( width: keySpec.width,
                               height: keySpec.height,
                               alignment: .center)
                        .cornerRadius(keySpec.radius)
//                        .shadow(radius: keySpec.radius)
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


