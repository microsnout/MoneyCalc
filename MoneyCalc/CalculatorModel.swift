//
//  CalculatorModel.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import Foundation
import Numerics
import OSLog

let logM = Logger(subsystem: "com.microsnout.calculator", category: "model")


enum KeyCode: Int {
    case key0 = 0, key1, key2, key3, key4, key5, key6, key7, key8, key9
    
    case plus = 10, minus, times, divide
    
    case dot = 20, enter, clear, back, sign, eex
    
    case fixL = 30, fixR, roll, xy, lastx, sto, rcl, mPlus, mMinus
    
    case y2x = 40, inv, x2, sqrt
    
    case fn0 = 50, sin, cos, tan, log, ln, pi, asin, acos, atan, tenExp, eExp, e
    
    case fix = 70, sci, eng, percent, currency
    
    case deg = 80, rad, sec, min, hr, yr, mm, cm, m, km
    
    case sk0 = 90, sk1, sk2, sk3, sk4, sk5, sk6
}


struct UndoStack {
    private let maxItems = 12
    private var storage = [CalcState]()
    
    mutating func push(_ state: CalcState ) {
        storage.append(state)
        if storage.count > maxItems {
            storage.removeFirst()
        }
    }
    
    mutating func pop() -> CalcState? {
        storage.popLast()
    }
}


protocol StateOperator {
    func transition(_ s0: CalcState ) -> CalcState?
}


class CalculatorModel: ObservableObject, KeyPressHandler {
    // Current Calculator State
    @Published var state = CalcState()

    var undoStack = UndoStack()

    // Display window into register stack
    static let displayRows = 3
    var rowCount: Int { return CalculatorModel.displayRows }
    
    // Keycodes that are valid in data entry mode
    private let entryKeys:Set<KeyCode> = [.key0, .key1, .key2, .key3, .key4, .key5, .key6, .key7, .key8, .key9, .dot, .sign, .back, .eex]
    
    private func bufferIndex(_ stackIndex: Int ) -> Int {
        // Convert a bottom up index into the stack array to a top down index into the displayed registers
        return CalculatorModel.displayRows - stackIndex - 1
    }
    
    func getRow( index: Int ) -> RowDataItem {
        let stkIndex = bufferIndex(index)
        
        return state.stackRow(stkIndex)
    }
    
    func memoryOp( key: KeyCode, index: Int ) {
        undoStack.push(state)
        state.acceptTextEntry()

        // Leading edge swipe operations
        switch key {
        case .rcl:
            state.stackLift()
            state.Xtv = state.memory[index].value
            break
            
        case .sto:
            state.memory[index].value = state.Xtv
            break
            
        case .mPlus:
            if state.Xt == state.memory[index].value.tag {
                state.memory[index].value.reg += state.X
            }
            break

        case .mMinus:
            if state.Xt == state.memory[index].value.tag {
                state.memory[index].value.reg -= state.X
            }
            break

        default:
            break
        }
    }
    
    func addMemoryItem() {
        undoStack.push(state)
        state.acceptTextEntry()
        state.memory.append( NamedValue( value: state.Xtv) )
    }
    
    func delMemoryItems( set: IndexSet) {
        undoStack.push(state)
        state.clearEntry()
        state.memory.remove( atOffsets: set )
    }
    
    func renameMemoryItem( index: Int, newName: String ) {
        undoStack.push(state)
        state.clearEntry()
        state.memory[index].name = newName
    }
    
    struct UnaryOp: StateOperator {
        let parmType: TypeTag?
        let resultType: TypeTag?
        let function: (Double) -> Double
        
        init( parm: TypeTag? = nil, result: TypeTag? = nil, _ function: @escaping (Double) -> Double ) {
            self.parmType = parm
            self.resultType = result
            self.function = function
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            var s1 = s0
            
            if let xType = self.parmType {
                // Check type of parameter
                if !s1.convertX( toTag: xType) {
                    // Cannot convert to required type
                    return nil
                }
            }
            s1.X = function( s1.X )
            
            if let rType = self.resultType {
                s1.Xt = rType
            }
            return s1
        }
    }
    
    struct BinaryOpReal: StateOperator {
        let function: (Double, Double) -> Double
        
        init(_ function: @escaping (Double, Double) -> Double ) {
            self.function = function
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            if s0.Yt.uid != uidUntyped || s0.Xt.uid != uidUntyped {
                // Cannot use typed values
                return nil
            }
            
            var s1 = s0
            s1.stackDrop()
            s1.X = function( s0.Y, s0.X )
            return s1
        }
    }
    
    struct BinaryOpAdditive: StateOperator {
        let function: (Double, Double) -> Double
        
        init(_ function: @escaping (Double, Double) -> Double ) {
            self.function = function
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            if s0.Yt == tagUntyped && s0.Xt != tagUntyped {
                // Cannot convert X operand back to untyped
                return nil
            }
            else if s0.Xt == s0.Yt || s0.Xt == tagUntyped {
                // X is same as Y or X is untyped and can be tagged same as Y
                var s1 = s0
                s1.stackDrop()
                s1.X = function( s0.Y, s0.X )
                return s1
            }
            
            // Unit signatures must match
            if let xDef = TypeDef.typeDict[s0.Xt],
               let yDef = TypeDef.typeDict[s0.Yt]
            {
                let ucX = toUnitCode(from: xDef.tc)
                let ucY = toUnitCode(from: yDef.tc)
                
                if  getUnitSig(ucX) != getUnitSig(ucY) {
                    // Incompatible types
                    return nil
                }
                else {
                    var s1 = s0
                    var x0: Double = s0.X
                    s1.stackDrop()

                    for (yFac, xFac) in zip( yDef.tc, xDef.tc) {
                        let (yTag, yExp) = yFac
                        let (xTag, xExp) = xFac
                        
                        if let xfDef = TypeDef.typeDict[xTag],
                           let yfDef = TypeDef.typeDict[yTag]
                        {
                            // Convert x value to y units
                            x0 /= pow(xfDef.ratio, Double(xExp))
                            x0 *= pow(yfDef.ratio, Double(yExp))
                        }
                        else {
                            // Unknown type factor
                            return nil
                        }
                    }
                    
                    s1.X = function( s0.Y, x0 )
                    return s1
                }
            }
            else {
                // Unkown types
                return nil
            }
        }
    }
    
    struct BinaryOpMultiplicative: StateOperator {
        let kc: KeyCode
        
        init( _ key: KeyCode ) {
            self.kc = key
        }
        
        func _op( _ x: Double, _ y: Double ) -> Double {
            return kc == .times ? x*y : x/y
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            var s1 = s0
            s1.stackDrop()
            
            if s0.Yt.isType(.untyped) {
                // Scaling typed value by an untyped - tag unchanged
                s1.X = _op( s0.Y, s0.X )
                s1.Xt = s0.Xt
            }
            else if s0.Xt.isType(.untyped) {
                // Scaling typed value by an untyped
                s1.X = _op( s0.Y, s0.X )
                s1.Xt = s0.Yt
            }
            else {
                if let (tc, ratio) = typeProduct(s0.Yt, s0.Xt, quotient: kc == .divide ),
                   let tag = lookupTypeTag(tc)
                {
                    // Successfully produced new type tag
                    s1.X = _op(s0.Y, s0.X) * ratio
                    s1.Xt = tag
                }
                else {
                    // Cannot multiply these types
                    return nil
                }
            }
            
            return s1
        }
    }
    
    
    struct CustomOp: StateOperator {
        let block: (CalcState) -> CalcState?
        
        init(_ block: @escaping (CalcState) -> CalcState? ) {
            self.block = block
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            return block(s0)
        }
    }
    
    struct ConversionOp: StateOperator {
        let block: (TaggedValue) -> TaggedValue?
        
        init(_ block: @escaping (TaggedValue) -> TaggedValue? ) {
            self.block = block
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            var s1 = s0
            
            if let newTV = block( s0.Xtv ) {
                s1.Xtv = newTV
                return s1
            }
            else {
                return nil
            }
        }
    }
    
    struct Convert: StateOperator {
        let toType: TypeTag
        
        init( to: TypeTag ) {
            self.toType = to
        }
        
        init( sym: String ) {
            self.toType = TypeDef.symDict[sym, default: tagNone]
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            var s1 = s0

            if s1.convertX( toTag: toType) {
                s1.Xfmt = s0.Xfmt
                return s1
            }
            else {
                return nil
            }
        }
    }
    
    struct Constant: StateOperator {
        let value: Double
        let tag: TypeTag

        init( _ value: Double, tag: TypeTag = tagUntyped ) {
            self.value = value
            self.tag = tag
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            var s1 = s0
            s1.stackLift()
            s1.X = self.value
            s1.Xt = self.tag
            s1.Xfmt = CalcState.defaultFormat
            return s1
        }
    }
    
    let opTable: [KeyCode : StateOperator] = [
        .plus:  BinaryOpAdditive( + ),
        .minus: BinaryOpAdditive( - ),
        .times: BinaryOpMultiplicative( .times ),
        .divide: BinaryOpMultiplicative( .divide ),

        // Square root, inverse, x squared, y to the x
        .sqrt:  UnaryOp( sqrt ),
        .inv:   UnaryOp( { (x: Double) -> Double in return 1.0/x } ),
        .x2:    UnaryOp( { (x: Double) -> Double in return x*x } ),
        .y2x:   BinaryOpReal( pow ),
        
        // Math function row 0
        .sin:   UnaryOp( parm: tagRad, result: tagUntyped, sin ),
        .cos:   UnaryOp( parm: tagRad, result: tagUntyped, cos ),
        .tan:   UnaryOp( parm: tagRad, result: tagUntyped, tan ),
        
        .log:   UnaryOp( result: tagUntyped, log10 ),
        .ln:    UnaryOp( result: tagUntyped, log ),
        
        .pi:    Constant( Double.pi ),
        .e:     Constant( exp(1.0) ),
        
        .clear:
            // Clear X register
            CustomOp { s0 in
                var s1 = s0
                s1.Xtv = untypedZero
                s1.noLift = true
                return s1
            },
        
        .roll:
            // Roll down register stack
            CustomOp { s0 in
                var s1 = s0
                s1.stackRoll()
                return s1
            },
        
        .xy:
            // x Y exchange
            CustomOp { s0 in
                var s1 = s0
                s1.Ytv = s0.Xtv
                s1.Xtv = s0.Ytv
                return s1
            },
        
        .deg: Convert( sym: "deg" ),
        .rad: Convert( sym: "rad" ),
        .sec: Convert( sym: "sec" ),
        .min: Convert( sym: "min" ),
        .m:   Convert( sym: "m"   ),
        .km:  Convert( sym: "km"  )
    ]
    
    
    func EntryModeKeypress(_ keyCode: KeyCode ) -> Bool {
        if !entryKeys.contains(keyCode) {
            return false
        }
        
        if state.exponentEntry {
            switch keyCode {
            case .key0, .key1, .key2, .key3, .key4, .key5, .key6, .key7, .key8, .key9:
                // Append a digit to exponent
                if state.exponentText.starts( with: "-") && state.exponentText.count < 4 || state.exponentText.count < 3 {
                    state.appendExpEntry( String(keyCode.rawValue))
                }

            case .dot, .eex:
                // No op
                break
                
            case .sign:
                if state.exponentText.starts( with: "-") {
                    state.exponentText.removeFirst()
                }
                else {
                    state.exponentText.insert( "-", at: state.exponentText.startIndex )
                }

            case .back:
                if state.exponentText.isEmpty {
                    state.exponentEntry = false
                    state.entryText.removeLast(3)
                }
                else {
                    state.exponentText.removeLast()
                }
                
            default:
                // No op
                break

            }
        }
        else {
            switch keyCode {
            case .key0, .key1, .key2, .key3, .key4, .key5, .key6, .key7, .key8, .key9:
                // Append a digit
                state.appendTextEntry( String(keyCode.rawValue))
                
            case .dot:
                if !state.entryText.contains(".") {
                    state.appendTextEntry(".")
                }
                
            case .eex:
                state.startExpEntry()

            case .sign:
                state.flipTextSign()

            case .back:
                state.entryText.removeLast()
                
                if state.entryText.isEmpty {
                    // Clear X, exit entry mode, no further actions
                    state.clearEntry()
                    
                    // Backspaced all chars, cancel state change
                    if let lastState = undoStack.pop() {
                        state = lastState
                    }
                }

            default:
                // No op
                break
            }
        }
        
        return true
    }
    
    
    func keyPress(_ event: KeyEvent) {
        let ( _, keyCode) = event
        
        if state.entryMode && EntryModeKeypress(keyCode) {
            return
        }
        
        switch keyCode {
        case .key0, .key1, .key2, .key3, .key4, .key5, .key6, .key7, .key8, .key9:
            undoStack.push(state)
            state.stackLift()
            state.startTextEntry( String(keyCode.rawValue) )
            
        case .dot:
            undoStack.push(state)
            state.stackLift()
            state.startTextEntry( "0." )
            
        case .back:
            // Undo last operation by restoring previous state
            if let lastState = undoStack.pop() {
                state = lastState
            }
            
        case .enter:            // Push stack up, x becomes entry value
            undoStack.push(state)
            state.acceptTextEntry()
            state.stackLift()
            state.noLift = true
            
        case .fixL:
            var fmt: FormatRec = state.Xtv.fmt
            fmt.digits = max(1, fmt.digits-1)
            state.Xfmt = fmt
            
        case .fixR:
            var fmt: FormatRec = state.Xtv.fmt
            fmt.digits = min(15, fmt.digits+1)
            state.Xfmt = fmt
            
        case .fix:
            undoStack.push(state)
            state.acceptTextEntry()
            state.Xfmt.mode = .decimal
            
        case .sci:
            undoStack.push(state)
            state.acceptTextEntry()
            state.Xfmt.mode = .scientific
            
        case .percent:
            undoStack.push(state)
            state.acceptTextEntry()
            state.Xfmt = CalcState.defaultPercentFormat
            
        case .currency:
            undoStack.push(state)
            state.acceptTextEntry()
            state.Xfmt = CalcState.defaultCurrencyFormat

        default:
            if let op = opTable[keyCode] {
                // Transition to new calculator state based on operation
                undoStack.push(state)
                state.acceptTextEntry()
                
                if let newState = op.transition( state ) {
                    // Operation has produced a new state
                    state = newState
                    state.noLift = false
                }
                else {
                    // else no-op as there was no new state
                    if let lastState = undoStack.pop() {
                        state = lastState
                    }
                }
            }
        }
    }
}
