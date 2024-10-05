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


func isInt( _ x: Double ) -> Int? {
    /// Test if a Double is an integer
    /// Valid down to 1.0000000000000005 or about 16 significant digits
    ///
    x == floor(x) ? Int(x) : nil
}

func isEven( _ x: Int ) -> Bool {
    // Return true if x is evenly divisible by 2.
    x % 2 == 0
}


enum KeyCode: Int {
    case key0 = 0, key1, key2, key3, key4, key5, key6, key7, key8, key9
    
    case plus = 10, minus, times, divide
    
    case dot = 20, enter, clear, back, sign, eex
    
    case fixL = 30, fixR, roll, xy, lastx, sto, rcl, mPlus, mMinus
    
    case y2x = 40, inv, x2, sqrt
    
    case fn0 = 50, sin, cos, tan, log, ln, pi, asin, acos, atan
    
    case tenExp = 60, eExp, e
    
    case fix = 70, sci, eng, percent, currency
    
    case deg = 80, rad, sec, min, hr, yr, mm, cm, m, km
    
    case noop = 90
    
    case sk0 = 100, sk1, sk2, sk3, sk4, sk5, sk6
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
            if let ratio = typeAddable( s0.Yt, s0.Xt) {
                // Operation is possible with scaling of X value
                var s1 = s0
                s1.stackDrop()
                s1.X = function( s0.Y, s0.X * ratio )
                return s1
            }
            else {
                // New state not possible
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
            
            if let (tag, ratio) = typeProduct(s0.Yt, s0.Xt, quotient: kc == .divide )
            {
                // Successfully produced new type tag
                s1.X = _op(s0.Y, s0.X) * ratio
                s1.Xt = tag
            }
            else {
                // Cannot multiply these types
                return nil
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

        // Math function row 0
        .sin:   UnaryOp( parm: tagRad, result: tagUntyped, sin ),
        .cos:   UnaryOp( parm: tagRad, result: tagUntyped, cos ),
        .tan:   UnaryOp( parm: tagRad, result: tagUntyped, tan ),
        
        .log:   UnaryOp( result: tagUntyped, log10 ),
        .ln:    UnaryOp( result: tagUntyped, log ),
        
        .tenExp: UnaryOp( parm: tagUntyped, result: tagUntyped, { x in pow(10.0, x) } ),
        .eExp: UnaryOp( parm: tagUntyped, result: tagUntyped, { x in exp(x) } ),

        .pi:    Constant( Double.pi ),
        .e:     Constant( exp(1.0) ),
        
        .sqrt:
            CustomOp { s0 in
                if s0.Xt == tagUntyped {
                    // Simple case, X is untyped value
                    var s1 = s0
                    s1.X = sqrt(s0.X)
                    return s1
                }
                
                if let tag = typeNthRoot(s0.Xt, n: 2) {
                    // Successful nth root of type tag
                    var s1 = s0
                    s1.Xtv = TaggedValue(tag, sqrt(s0.X), format: s0.Xfmt)
                    return s1
                }
                
                // Failed operation
                return nil
            },
        
        .y2x:
            CustomOp { s0 in
                if s0.Xt != tagUntyped {
                    // Exponent must be untyped value
                    return nil
                }
                
                if s0.Yt == tagUntyped {
                    // Simple case, both operands untyped
                    var s1 = s0
                    s1.stackDrop()
                    s1.X = pow(s0.Y, s0.X)
                    return s1
                }
                
                if let exp = isInt(s0.X),
                   let tag = typeExponent( s0.Yt, x: exp )
                {
                    // Successful type exponentiation
                    var s1 = s0
                    s1.stackDrop()
                    s1.Xtv = TaggedValue(tag, pow(s0.Y, s0.X), format: s0.Yfmt)
                    return s1
                }
                
                // Failed operation
                return nil
            },
        
        .x2:
            CustomOp { s0 in
                var s1 = s0
                if let (tag, ratio) = typeProduct(s0.Xt, s0.Xt) {
                    s1.Xtv = TaggedValue(tag, s0.X * s0.X, format: s0.Xfmt)
                    return s1
                }
                return nil
            },
        
        .inv:
            CustomOp { s0 in
                var s1 = s0
                if let (tag, ratio) = typeProduct(tagUntyped, s0.Xt, quotient: true) {
                    s1.Xtv = TaggedValue(tag, 1.0 / s0.X, format: s0.Xfmt)
                    return s1
                }
                return nil
            },
        
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
            // Any key other than valid Entry mode keys cause en exit from the mode
            // with acceptance of the entered value
            state.acceptTextEntry()
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
                state.appendTextEntry(".")
                
            case .eex:
                state.startExpEntry()

            case .sign:
                state.flipTextSign()

            case .back:
                state.backspaceEntry()
                
                if !state.entryMode {
                    // Exited entry mode
                    // Return false so .back is processed as a non entry mode undo
                    return false
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
            // We are in Entry mode and this event has been processed and we stay in this mode
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
            
        case .enter:
            // Push stack up, x becomes entry value
            undoStack.push(state)
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
            state.Xfmt.mode = .decimal
            
        case .sci:
            undoStack.push(state)
            state.Xfmt.mode = .scientific
            
        case .percent:
            undoStack.push(state)
            state.Xfmt = CalcState.defaultPercentFormat
            
        case .currency:
            undoStack.push(state)
            state.Xfmt = CalcState.defaultCurrencyFormat

        default:
            if let op = opTable[keyCode] {
                // Transition to new calculator state based on operation
                undoStack.push(state)
                
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
