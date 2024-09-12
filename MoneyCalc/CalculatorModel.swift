//
//  CalculatorModel.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import Foundation
import Numerics
import OSLog

let logM = Logger(subsystem: "com.microsnout.calculator", category: "main")


enum KeyCode: Int {
    case key0 = 0, key1, key2, key3, key4, key5, key6, key7, key8, key9
    
    case plus = 10, minus, times, divide
    
    case dot = 20, enter, clear, back, sign, eex
    
    case fixL = 30, fixR, roll, xy, percent, lastx, sto, rcl, mPlus, mMinus
    
    case y2x = 40, inv, x2, sqrt
    
    case fn0 = 50, sin, cos, tan, log, ln, pi, asin, acos, atan, tenExp, eExp, e
    
    case fix = 70, sci, eng
    
    case deg = 80, rad, sec, min, hr, yr, mm, cm, m, km
    
    case sk0 = 90, sk1, sk2, sk3, sk4, sk5, sk6
}


enum PadCode: Int {
    case padDigits = 0, padOp, padEnter, padClear, padUnit, padFn0
}


// Standard HP calculator registers
let stackPrefixValues = ["X", "Y", "Z", "T"]

// Register index values
let regX = 0, regY = 1, regZ = 2, regT = 3, stackSize = 4

typealias FormatMode = NumberFormatter.Style

struct FormatRec {
    var mode: FormatMode = .decimal
    var digits: Int = 4
}

struct TaggedValue {
    var tag: TypeTag
    var reg: Double
    var fmt: FormatRec
    
    var uid: UnitId { self.tag.uid }
    var tid: TypeId { self.tag.tid }
    
    func isUnit( _ uid: UnitId ) -> Bool {
        return self.tag.uid == uid
    }
    
    init( _ tag: TypeTag, _ reg: Double = 0.0, format: FormatRec = FormatRec() ) {
        self.tag = tag
        self.reg = reg
        self.fmt = format
    }
}

let untypedZero: TaggedValue = TaggedValue(tagUntyped)
let valueNone: TaggedValue = TaggedValue(tagNone)

struct NamedValue {
    var name: String?
    var value: TaggedValue
    
    func isType( _ tt: TypeTag ) -> Bool {
        return value.tag == tt
    }
    
    init(_ name: String? = nil, value: TaggedValue ) {
        self.name = name
        self.value = value
    }
}

struct RegisterRow: RowDataItem {
    var prefix: String?
    var register: String
    var regAddon: String?
    var exponent: String?
    var expAddon: String?
    var suffix: String?
}

struct CalcState {
    var stack: [NamedValue] = stackPrefixValues.map { NamedValue( $0, value: untypedZero) }
    var lastX: TaggedValue = untypedZero
    var noLift: Bool = false
    var memory = [NamedValue]()
    var defaultFormat: FormatRec = FormatRec( mode: .decimal, digits: 4 )
    
    // Data entry state
    var entryMode: Bool = false
    var exponentEntry: Bool = false
    var entryText: String = ""
    var exponentText: String = ""
    
    mutating func convertX( toTag: TypeTag ) -> Bool {
        if let seq = unitConvert( from: Xt, to: toTag ) {
            Xtv = TaggedValue( toTag, seq.op(X) )
            return true
        }
        
        // Failed to find conversion
        return false
    }
    
    private func regRow( _ nv: NamedValue ) -> RegisterRow {
        if nv.isType(tagNone) {
            return RegisterRow( prefix: nv.name, register: "-")
        }
        
        let fmt = nv.value.fmt
        
        let nf = NumberFormatter()
        nf.numberStyle = fmt.mode
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = fmt.digits

        let str = nf.string(for: nv.value.reg) ?? ""

        let strParts = str.split( separator: "E" )
        
        if strParts.count == 2 {
            return RegisterRow(
                prefix: nv.name,
                register: String(strParts[0]) + "x10",
                exponent: String(strParts[1]),
                suffix: nv.value.tag.symbol)
        }
        else {
            return RegisterRow(
                prefix: nv.name,
                register: String(strParts[0]),
                suffix: nv.value.tag.symbol)
        }
    }
    
    func stackRow( _ index: Int ) -> RegisterRow {
        if self.entryMode && index == regX {
            return RegisterRow(
                prefix: self.stack[regX].name,
                register: self.entryText,
                regAddon: self.exponentEntry ? nil : "_",
                exponent: self.exponentEntry ? self.exponentText : nil,
                expAddon: self.exponentEntry ? "_" : nil )
        }
        
        return regRow( self.stack[index] )
    }
    
    func memoryRow( _ index: Int ) -> RegisterRow {
        guard index >= 0 && index < self.memory.count else {
            return RegisterRow( register: "Error" )
        }
        
        return regRow( self.memory[index] )
    }
    
    var memoryList: [RegisterRow] {
        get {
            (0 ..< self.memory.count).map { self.memoryRow($0) }
        }
    }
    
    mutating func clearEntry() {
        self.entryMode = false
        self.exponentEntry = false
        self.entryText.removeAll(keepingCapacity: true)
        self.exponentText.removeAll(keepingCapacity: true)
        
        logM.debug( "ClearEntry" )
    }

    mutating func startTextEntry(_ str: String ) {
        self.clearEntry()
        self.entryMode = true
        self.entryText = str
        
        logM.debug("StartTextEntry: \(str)")
    }
    
    mutating func acceptTextEntry() {
        if self.entryMode {
            var num: String = self.entryText
            
            logM.debug( "AcceptTextEntry: \(num)")
            
            if exponentEntry {
                /// Eliminate 'x10'
                num.removeLast(3)
            }

            if exponentEntry && !exponentText.isEmpty {
                /// Exponential entered
                let str: String = num + "E" + exponentText
                stack[regX].value.reg = Double(str)!
                stack[regX].value.tag = tagUntyped
                stack[regX].value.fmt.mode = .scientific
            }
            else {
                stack[regX].value.reg = Double(num)!
                stack[regX].value.tag = tagUntyped
                stack[regX].value.fmt.mode = .decimal
            }
            clearEntry()
        }
    }
    
    mutating func appendTextEntry(_ str: String ) {
        self.entryText += str
        
        let txt = self.entryText
        logM.debug( "AppendTextEntry: '\(str)' -> '\(txt)'")
    }
    
    mutating func appendExponentEntry(_ str: String ) {
        self.exponentText += str
        
        let txt = self.exponentText
        logM.debug( "AppendExponentEntry: '\(str)' -> '\(txt)'")
    }

    var X: Double {
        get { stack[regX].value.reg }
        set { stack[regX].value.reg = newValue }
    }
    
    var Xt: TypeTag {
        get { stack[regX].value.tag }
        set { stack[regX].value.tag = newValue }
    }
    
    var Xfmt: FormatRec {
        get { stack[regX].value.fmt }
        set { stack[regX].value.fmt = newValue }
    }
    
    var Xtv: TaggedValue {
        get { stack[regX].value }
        set { self.Xt = newValue.tag; self.X = newValue.reg; self.Xfmt = newValue.fmt }
    }
    
    var Y: Double {
        get { stack[regY].value.reg }
        set { stack[regY].value.reg = newValue }
    }
    
    var Yt: TypeTag {
        get { stack[regY].value.tag }
        set { stack[regY].value.tag = newValue }
    }
    
    var Ytv: TaggedValue {
        get { stack[regY].value }
        set { self.Yt = newValue.tag; self.Y = newValue.reg }
    }
    
    var Z: Double {
        get { stack[regZ].value.reg }
        set { stack[regZ].value.reg = newValue }
    }
    
    var T: Double {
        get { stack[regT].value.reg }
        set { stack[regT].value.reg = newValue }
    }
    
    mutating func stackDrop(_ by: Int = 1 ) {
        for rx in regX ..< stackSize-1 {
            self.stack[rx].value = self.stack[rx+1].value
        }
    }

    mutating func stackLift(_ by: Int = 1 ) {
        if self.noLift {
            logM.debug("stackLift: No-op")
            self.noLift = false
            return
        }
        
        logM.debug("stackLift: LIFT")
        for rx in stride( from: stackSize-1, to: regX, by: -1 ) {
            self.stack[rx].value = self.stack[rx-1].value
        }
    }

    mutating func stackRoll() {
        let xtv = self.Xtv
        stackDrop()
        let last = stackSize-1
        self.stack[last].value = xtv
    }
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
    static let displayRows = 4
    var rowCount: Int { return CalculatorModel.displayRows }
    
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
        state.acceptTextEntry()
        undoStack.push(state)
        state.memory.append( NamedValue( value: state.Xtv) )
    }
    
    func delMemoryItems( set: IndexSet) {
        state.clearEntry()
        undoStack.push(state)
        state.memory.remove( atOffsets: set )
    }
    
    func renameMemoryItem( index: Int, newName: String ) {
        state.clearEntry()
        undoStack.push(state)
        state.memory[index].name = newName
    }
    
    class UnaryOp: StateOperator {
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
    
    class BinaryOpReal: StateOperator {
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
    
    class BinaryOpAdditive: StateOperator {
        let function: (Double, Double) -> Double
        
        init(_ function: @escaping (Double, Double) -> Double ) {
            self.function = function
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            if s0.Yt.uid == uidUntyped && s0.Xt.uid != uidUntyped {
                // Cannot convert X operand back to untyped
                return nil
            }
            
            // Result will be same type as Y
            var s1 = s0
            s1.stackDrop()

            if s0.Yt == s0.Xt {
                // Identical types
                s1.X = function( s0.Y, s0.X )
                return s1
            }
            
            // Op not possible
            return nil
        }
    }
    
    class BinaryOpMultiplicative: StateOperator {
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
    
    
    class CustomOp: StateOperator {
        let block: (CalcState) -> CalcState?
        
        init(_ block: @escaping (CalcState) -> CalcState? ) {
            self.block = block
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            return block(s0)
        }
    }
    
    class ConversionOp: StateOperator {
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
    
    class Convert: StateOperator {
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
                return s1
            }
            else {
                return nil
            }
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
        
        .enter:
            // Push stack up, x becomes entry value
            CustomOp { s0 in
                var s1 = s0
                s1.stackLift()
                s1.noLift = true
                return s1
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
            return false
        }
        
        if state.exponentEntry {
            switch keyCode {
            case .key0, .key1, .key2, .key3, .key4, .key5, .key6, .key7, .key8, .key9:
                // Append a digit to exponent
                if state.exponentText.starts( with: "-") && state.exponentText.count < 4 || state.exponentText.count < 3 {
                    state.appendExponentEntry( String(keyCode.rawValue))
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
                state.appendTextEntry("×10")
                state.exponentText = ""
                state.exponentEntry = true

            case .sign:
                if state.entryText.starts( with: "-") {
                    state.entryText.removeFirst()
                }
                else {
                    state.entryText.insert( "-", at: state.entryText.startIndex )
                }

            case .back:
                state.entryText.removeLast()
                if state.entryText.isEmpty {
                    // Clear X, exit entry mode, no further actions
                    state.clearEntry()
                    state.noLift = true
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
            state.startTextEntry( String(keyCode.rawValue) )
            state.stackLift()
            
        case .dot:
            state.startTextEntry( "0." )
            state.stackLift()
            
        case .back:
            // Undo last operation by restoring previous state
            if let lastState = undoStack.pop() {
                state = lastState
            }
            
        case .fixL:
            var fmt: FormatRec = state.Xtv.fmt
            fmt.digits = max(1, fmt.digits-1)
            state.Xfmt = fmt
            
        case .fixR:
            var fmt: FormatRec = state.Xtv.fmt
            fmt.digits = min(15, fmt.digits+1)
            state.Xfmt = fmt

//        case .fix, .sci:
//            let fmt: FormatRecord = state.getFormat(tag: self.state.Xt )
//            let map: [KeyCode : FormatMode] = [.fix : .decimal, .sci : .scientific]
//            fmt.mode = map[keyCode]!
//            state.updateFormat( self.state.Xt, newFmt: fmt)
//            
        case .pi:
            undoStack.push(state)
            state.stackLift()
            state.Xtv = TaggedValue( TypeTag(.untyped), Double.pi )
            
        default:
            if let op = opTable[keyCode] {
                // Transition to new calculator state based on operation
                undoStack.push(state)
                state.acceptTextEntry()
                if let newState = op.transition( state ) {
                    state = newState
//                    state.noLift = false
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

extension Double {
    func displayFormat(_ mode: FormatMode, _ digits: Int, _ minDigits: Int ) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = mode
        nf.minimumFractionDigits = minDigits
        nf.maximumFractionDigits = digits
        return nf.string(for: self) ?? ""
    }
}


