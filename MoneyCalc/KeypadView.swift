//
//  KeypadView.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//  Continuing 2024
//

import SwiftUI

typealias KeyID = Int
typealias PadID = Int
typealias RowID = Int

typealias  KeyEvent = ( pad: PadCode, key: KeyCode )

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
    var kc: KeyCode
    var size: Int           // Either 1 or 2, single width keys or double width
    var text: String?
    var fontSize:Double?
    var image: ImageResource?
    
    var id: Int { return self.kc.rawValue }

    init(_ kc: KeyCode, _ label: String? = nil, size: Int = 1, fontSize: Double? = nil, image: ImageResource? = nil ) {
        self.kc = kc
        self.text = label
        self.size = size
        self.fontSize = fontSize
        self.image = image
    }
}

struct PadSpec {
    var pc: PadCode
    var rows: Int = 1
    var cols: Int = 1
    var keys: [Key]
    var fontSize = 20.0
    var caption: String?
}

struct Keypad: View {
    
    var keySpec: KeySpec
    var padSpec: PadSpec
    
    var keyPressHandler:  KeyPressHandler
    
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    private var columns: [GridItem] {
        Array(repeating: .init(.fixed(keySpec.width)), count: padSpec.cols)
    }
    
    init( keySpec: KeySpec, padSpec: PadSpec, keyPressHandler: KeyPressHandler ) {
        self.keySpec = keySpec
        self.padSpec = padSpec
        self.keyPressHandler = keyPressHandler
        
        impactFeedback.prepare()
    }
    
    var body: some View {
        LazyVGrid(
            columns: columns,
            alignment: .leading,
            spacing: keySpec.spacing
        ) {
            ForEach(padSpec.keys) { key in
                Button( action: {
                    keyPressHandler.keyPress( (padSpec.pc, key.kc) )
                    impactFeedback.impactOccurred()
                })
                {
                    if let image = key.image {
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
                                Image(image).renderingMode(.template).foregroundColor(keySpec.textColor), alignment: .center)
                    }
                    else if let label = key.text {
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
                                Text(label)
                                    .font(.system(size: key.fontSize == nil ? padSpec.fontSize : key.fontSize! ))
                                    .background( keySpec.buttonColor)
                                    .foregroundColor( keySpec.textColor),
                                alignment: .center)
                    }
                }
                
                if key.size == 2 { Color.clear }
             }
        }
        .frame( width: (keySpec.width + keySpec.spacing) * Double(padSpec.cols))
        .padding( .vertical, 5 )
    }
}

// ********************************************

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}


extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `ifelse`<Content: View>(_ condition: Bool, transform: (Self) -> Content, elseT: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            elseT(self)
        }
    }
}


struct SoftKeyRow: View {
    var keySpec: KeySpec
    var rowSpec: PadSpec
    
    var keyPressHandler:  KeyPressHandler
    
    var body: some View {
        HStack {
            ForEach(rowSpec.keys, id: \.id) { key in
                Button( action: {} )
                {
                    Spacer()
                    if let image = key.image {
                        Rectangle()
                            .foregroundColor(keySpec.buttonColor)
                            .frame( width: keySpec.width,
                                    height: keySpec.height,
                                    alignment: .center)
                            .cornerRadius(keySpec.radius)
                            .overlay(
                                Image(image).renderingMode(.template).foregroundColor(keySpec.textColor), alignment: .center)
                    }
                    else if let label = key.text {
                        Rectangle()
                            .foregroundColor(keySpec.buttonColor)
                            .frame( width: keySpec.width,
                                   height: keySpec.height,
                                   alignment: .center)
                            .cornerRadius(keySpec.radius)
                            .overlay(
                                Text( "\(label)")
                                    .font(.system(size: key.fontSize == nil ? rowSpec.fontSize : key.fontSize! ))
                                    .background( keySpec.buttonColor)
                                    .foregroundColor( keySpec.textColor),
                                alignment: .center)
                        
                    }
                    Spacer()
                }
                .simultaneousGesture( LongPressGesture().onEnded { _ in
                    print("Secret Long Press Action!")
                })
                .simultaneousGesture( TapGesture().onEnded {
                    print("Boring regular tap")
                    keyPressHandler.keyPress( (rowSpec.pc, key.kc) )
                })
             }
        }
        
//  Rectangle around rows with caption text
//        .padding( .vertical, 12 )
//        .overlay(
//            Rectangle()
//                .stroke( Color("Frame") )
//                .foregroundColor( Color.clear )
//                .overlay(
//                    Text( rowSpec.caption )
//                        .padding( .horizontal, 5 )
//                        .background( Color("Background") )
//                        .foregroundColor( Color("Frame") )
//                        .font(.system(size: 10.0 ))
//                        .alignmentGuide(.leading, computeValue: {_ in -10})
//                        .alignmentGuide(.top, computeValue: {_ in 7})
//                        ,
//                   alignment: .topLeading
//                )
//        )
        
    }
}


