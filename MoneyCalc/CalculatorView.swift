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

enum PadCode: Int {
    case padDigits = 0, padOp, padEnter, padClear, padUnit, padFn0, padFn1, padFmt, padLog, padSin
    
    var spec: PadSpec? {
        PadSpec.specList[self]
    }
}



// ******************


struct CalculatorView: View {
    @StateObject  var model = CalculatorModel()
    
    let keySpec = KeySpec(
        width: 43, height: 40,
        radius: 10, spacing: 10,
        buttonColor: Color("KeyColor"), textColor: Color("KeyText"))
    
    let numPad = PadSpec(
        pc: .padDigits,
        cols: 3,
        keys: [ Key(.key7, "7"), Key(.key8, "8"), Key(.key9, "9"),
                Key(.key4, "4"), Key(.key5, "5"), Key(.key6, "6"),
                Key(.key1, "1"), Key(.key2, "2"), Key(.key3, "3"),
                Key(.key0, "0"), Key(.dot, "."),  Key(.sign, "+/-", fontSize: 15)
              ])
    
    let opPad = PadSpec(
        pc: .padOp,
        cols: 3,
        keys: [ Key(.divide, "÷"), Key(.fixL, ".00\u{2190}", fontSize: 12), Key(.y2x, image: .yx),
                Key(.times, "×"),  Key(.lastx, "LASTx", fontSize: 10), Key(.inv, image: .onex),
                Key(.minus, "−"),  Key(.xy, "X\u{21c6}Y", fontSize: 12),    Key(.x2, image: .x2),
                Key(.plus,  "+"),  Key(.roll, "R\u{2193}", fontSize: 12),   Key(.sqrt, image: .rx)
              ])
    
    let enterPad = PadSpec(
        pc: .padEnter,
        cols: 3,
        keys: [ Key(.enter, "Enter", size: 2, fontSize: 15), Key(.eex, "EE", fontSize: 15)
              ])
    
    let clearPad = PadSpec(
        pc: .padClear,
        cols: 3,
        keys: [ Key(.back, "BACK/UNDO", size: 2, fontSize: 12), Key(.clear, "CLx", fontSize: 12)
              ])
    

    // *** Popup Keypads ***

    let sinPad = PadSpec (
        pc: .padSin,
        cols: 2,
        keys: [ Key(.sin, "sin"),
                Key(.cos, "cos"),
                Key(.tan,  "tan")],
        fontSize: 18.0,
        caption: "Log Pad Popup"
    )

    let logPad = PadSpec (
        pc: .padLog,
        cols: 2,
        keys: [ Key(.log, "log"),
                Key(.ln,  "ln")],
        fontSize: 18.0,
        caption: "Log Pad Popup"
    )


    // **************************
    
    let skSpec = KeySpec(
        width: 43, height: 30,
        radius: 10, spacing: 10,
        buttonColor: Color("KeyColor"), textColor: Color("KeyText"))
    
    let unitRowSpec = PadSpec (
        pc: .padUnit,
        cols: 6,
        keys: [ Key(.deg, "deg"),
                Key(.rad, "rad"),
                Key(.sec, "sec"),
                Key(.min, "min"),
                Key(.m,   "m"),
                Key(.km,  "km")
              ],
        fontSize: 15.0
    )
    
    let fn0RowSpec = PadSpec (
        pc: .padFn0,
        cols: 6,
        keys: [ Key(.sin, "sin..", popup: .padSin),
                Key(.cos, "cos"),
                Key(.tan, "tan"),
                Key(.log, "log..", fontSize: 14, popup: .padLog),
                Key(.ln,   "ln"),
                Key(.pi,  "\u{1d70b}", fontSize: 20)
            ],
        fontSize: 14.0
    )
    
    let fn1RowSpec = PadSpec (
        pc: .padFn1 ,
        cols: 6,
        keys: [ Key(.noop, " "),
                Key(.noop, " "),
                Key(.noop, " "),
                Key(.tenExp, image: .tenx),
                Key(.eExp,   image: .ex),
                Key(.e,      image: .e)
            ],
        fontSize: 14.0
    )
    
    let fmtRowSpec = PadSpec (
        pc: .padFmt,
        cols: 6,
        keys: [ Key(.fix, "fix"),
                Key(.sci, "sci"),
                Key(.percent, "%"),
                Key(.currency, "$"),
                Key(.fixL, ".00\u{2190}", fontSize: 12.0),
                Key(.fixR, ".00\u{2192}", fontSize: 12.0),
            ],
        fontSize: 14.0
    )
    

    // **************************
    
    let swipeLeadingOpTable: [(KeyCode, String, Color)] = [
        ( .rcl,    "RCL", .mint ),
        ( .sto,    "STO", .indigo ),
        ( .mPlus,  "M+",  .cyan  ),
        ( .mMinus, "M-",  .green )
    ]
    
    @State private var location: CGPoint = CGPoint( x: 0, y: 0)
    @State private var movement: CGSize = CGSize.zero
    
    @State private var popPad: PadSpec? = nil
    @Namespace private var nsPopPad
    
    var dragBoundry: some Gesture {
        DragGesture()
            .onChanged { value in
                self.movement = value.translation
                print(self.movement)
            }
    }

    
    @ViewBuilder
    private var customModal: some View {
        if popPad != nil {
            Rectangle()
                .opacity(0.0001)
        }
    }
    

    @ViewBuilder
    private var customPopover: some View {
        if let popPad {
            Keypad(
                popPad: $popPad, ns: nsPopPad,
                keySpec: skSpec, padSpec: popPad,
                keyPressHandler: model
            )
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color("Background"))
                        .shadow(radius: 6)
                }
                .matchedGeometryEffect(
                    id: popPad.pc,
                    in: nsPopPad,
                    properties: .position,
                    anchor: .bottom,
                    isSource: false
                )
        }
    }

    
    var body: some View {
        ZStack(alignment: .center) {
            Rectangle()
                .fill(Color("Display"))
                .edgesIgnoringSafeArea( .all )
            
            ZStack
            {
                VStack
                {
                    MemoryDisplay( model: model, leadingOps: swipeLeadingOpTable )
                    VStack(alignment: .center) {
                        // App name and drag handle
                        HStack {
                            Text("HP 33").foregroundColor(.black)/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/().italic()
                            Spacer()
                            Image("drag-vertical")
                                .resizable().scaledToFit()
                                .gesture( dragBoundry )
                        }
                        .frame( height: 25 )
                        
                        // Main calculator display
                        Display( model: model )
                        
                        Keypad( popPad: $popPad, ns: nsPopPad,
                                    keySpec: skSpec, padSpec: unitRowSpec, keyPressHandler: model )
                            .padding( .vertical, 1 )
                        
                        Keypad( popPad: $popPad, ns: nsPopPad,
                                    keySpec: skSpec, padSpec: fn1RowSpec, keyPressHandler: model )
                            .padding( .vertical, 1 )
                        
                        Keypad( popPad: $popPad, ns: nsPopPad,
                                    keySpec: skSpec, padSpec: fn0RowSpec, keyPressHandler: model )
                            .padding( .vertical, 1 )
                        
                        Divider()
                        
                        // Standard keypads
                        VStack( alignment: .leading) {
                            HStack {
                                Keypad( popPad: $popPad, ns: nsPopPad, keySpec: keySpec, padSpec: numPad, keyPressHandler: model )
                                Keypad( popPad: $popPad, ns: nsPopPad, keySpec: keySpec, padSpec: opPad, keyPressHandler: model )
                            }
                            HStack {
                                Keypad( popPad: $popPad, ns: nsPopPad, keySpec: keySpec, padSpec: enterPad, keyPressHandler: model)
                                Keypad( popPad: $popPad, ns: nsPopPad, keySpec: keySpec, padSpec: clearPad, keyPressHandler: model)
                            }
                        }.alignmentGuide(.leading, computeValue: {_ in 0})
                        
                        Divider()

                        Keypad( popPad: $popPad, ns: nsPopPad,
                                    keySpec: skSpec, padSpec: fmtRowSpec, keyPressHandler: model )
                            .padding( .vertical, 1 )
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 5)
                    .background( Color("Background"))
                }
                .ignoresSafeArea(.keyboard)
                
                customModal
                    .onTapGesture {
                        popPad = nil
                    }

                customPopover
                    .transition(
                        .opacity.combined(with: .scale)
                        .animation(.bouncy(duration: 0.25, extraBounce: 0.2))
                    )
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

