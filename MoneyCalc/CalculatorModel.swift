//
//  CalculatorModel.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import Foundation
import Numerics


enum KeyCode: Int {
    case key0 = 0, key1, key2, key3, key4, key5, key6, key7, key8, key9
    
    case plus = 10, minus, times, divide
    
    case dot = 20, enter, clear, back, sign, eex
    
    case fixL = 30, fixR, roll, xy, percent, lastx, sto, rcl, mPlus, mMinus
    
    case y2x = 40, inv, x2, sqrt
    
    case fn0 = 50, sin, cos, tan, log, ln, pi, asin, acos, atan, tenExp, eExp, e
    
    case sk0 = 90, sk1, sk2, sk3, sk4, sk5, sk6
}


enum PadCode: Int {
    case padDigits = 0, padOp, padEnter, padClear, padFiat, padFn0
}


// Standard HP calculator registers
let stackPrefixValues = ["X", "Y", "Z", "T"]

// Register index values
let regX = 0, regY = 1, regZ = 2, regT = 3, stackSize = 4

enum TypeCode: Int {
    case untyped = 0, percentage, fiat, crypto, shares, time, compound
}

typealias TypeIndex = Int

//typealias TypeTag = ( code: TypeCode, index: TypeIndex)

struct TypeTag: Hashable {
    var code: TypeCode
    var index: TypeIndex
    
    init( _ code: TypeCode, _ index: TypeIndex ) {
        self.code = code
        self.index = index
    }
}

typealias TaggedValue = (tag: TypeTag, reg: Double )

let tagUntyped: TypeTag = TypeTag(.untyped, 0)

let untypedZero: TaggedValue = (tagUntyped, 0.0)

enum FormatMode: Int {
    case varMode = 0, fixMode, sciMode, engMode
}

protocol TypeRecord {
    var suffix: String? { get }
    var mode: FormatMode { get set }
    var digits: Int { get set }
    var minDigits: Int { get set }
}

class TypeUntyped: TypeRecord {
    var suffix: String? = nil
    var mode: FormatMode = .varMode
    var digits: Int = 4
    var minDigits: Int = 1
    
    static let record = TypeUntyped()
}

class TypePercentage: TypeRecord {
    var suffix: String? { "%" }
    var mode: FormatMode = .varMode
    var digits: Int = 2
    var minDigits: Int = 1

    static let record = TypePercentage()
}

func getRecord(_ tag: TypeTag ) -> TypeRecord {
    
    switch tag.code {
    case .percentage:
        return TypePercentage.record
        
    case .crypto, .fiat:
        if let rec = TypeFinancial.getRecord(tag) {
            return rec
        }
        return TypeUntyped.record

    default:
        return TypeUntyped.record
    }
}

struct NamedValue: RowDataItem {
    var name: String?
    var value: TaggedValue
    
    init(_ name: String? = nil, value: TaggedValue ) {
        self.name = name
        self.value = value
    }
    
    var prefix: String? {
        return name
    }
    
    var register: String {
        let tr = getRecord( value.tag )
        return value.reg.displayFormat( tr.digits, tr.minDigits )
    }
    
    var exponent: String? {
        return nil
    }
    
    var suffix: String? {
        let tr = getRecord( value.tag )
        return tr.suffix
    }
}

extension MemoryItem {
    var typeClass: TypeCode {
        get {
            return TypeCode( rawValue: self.tagClass )!
        }
        
        set {
            self.tagClass = newValue.rawValue
        }
    }
    
    var tag: TypeTag {
        get {
            return TypeTag(self.typeClass, TypeIndex(self.tagIndex) )
        }
        
        set {
            self.tagClass = newValue.code.rawValue
            self.tagIndex = newValue.index
        }
    }
    
    var tv: TaggedValue {
        get {
            return ( self.tag, self.value )
        }
        
        set {
            self.tag = newValue.tag
            self.value = newValue.reg
        }
    }
    
    var namedValue: NamedValue {
        get {
            return NamedValue( self.name, value: self.tv )
        }
        
        set {
            self.name = newValue.name
            self.tv = newValue.value
        }
    }
}

struct CalcState {
    var stack: [NamedValue] = stackPrefixValues.map { NamedValue( $0, value: untypedZero) }
    var lastX: TaggedValue = untypedZero
    var noLift: Bool = false
    var memory = [NamedValue]()
    var formatMap: [ TypeTag : TypeRecord ] = [:]
    
    // Data entry state
    var entryMode: Bool = false
    var decimalSeen: Bool = false
    var exponentEntry: Bool = false
    var entryText: String = ""
    var exponentText: String = ""
    
    mutating func clearEntry() {
        self.entryMode = false
        self.decimalSeen = false
        self.exponentEntry = false
        self.entryText.removeAll(keepingCapacity: true)
        self.exponentText.removeAll(keepingCapacity: true)
    }

    var X: Double {
        get { stack[regX].value.reg }
        set { stack[regX].value.reg = newValue }
    }
    
    var Xt: TypeTag {
        get { stack[regX].value.tag }
        set { stack[regX].value.tag = newValue }
    }
    
    var Xtv: TaggedValue {
        get { (self.Xt, self.X) }
        set { self.Xt = newValue.tag; self.X = newValue.reg }
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
        get { (self.Yt, self.Y) }
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
            self.stack[rx].value.reg = self.stack[rx+1].value.reg
            self.stack[rx].value.tag = self.stack[rx+1].value.tag
        }
    }

    mutating func stackLift(_ by: Int = 1 ) {
        if self.noLift {
            self.noLift = false
            return
        }
        for rx in stride( from: stackSize-1, to: regX, by: -1 ) {
            self.stack[rx].value.reg = self.stack[rx-1].value.reg
            self.stack[rx].value.tag = self.stack[rx-1].value.tag
        }
    }

    mutating func stackRoll() {
        let xtv = self.Xtv
        stackDrop()
        let last = stackSize-1
        self.stack[last].value.reg = xtv.reg
        self.stack[last].value.tag = xtv.tag
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
    static let displayRows = 3
    var rowCount: Int { return CalculatorModel.displayRows }
    
    var memoryRows: [RowDataItem] { return state.memory }
    
    private let entryKeys:Set<KeyCode> = [.key0, .key1, .key2, .key3, .key4, .key5, .key6, .key7, .key8, .key9, .dot, .sign, .back, .eex]
    
    private func startTextEntry(_ str: String ) {
        state.clearEntry()
        state.entryMode = true
        state.entryText = str
        state.decimalSeen = str.contains(".")
    }
    
    private func acceptTextEntry() {
        if state.entryMode {
            var num: String = state.entryText
            if state.exponentEntry {
                num.removeLast(3)
            }
            let str: String = state.exponentEntry && !state.exponentText.isEmpty ? num + "E" + state.exponentText : num
            state.stack[regX].value.reg = Double(str)!
            state.stack[regX].value.tag = TypeTag(.untyped, 0)
            state.entryMode = false
        }
    }
    
    private func cancelTextEntry() {
        state.entryMode = false
        state.entryText = ""
    }
    
    private func bufferIndex(_ stackIndex: Int ) -> Int {
        // Convert a bottom up index into the stack array to a top down index into the displayed registers
        return CalculatorModel.displayRows - stackIndex - 1
    }
    
    func getRow( index: Int ) -> RowDataItem {
        let stkIndex = bufferIndex(index)
        
        if state.entryMode && stkIndex == regX {
            struct EntryRow: RowDataItem {
                var prefix: String?
                var register: String
                var exponent: String?
                var suffix: String? = nil
            }
            
            if state.exponentEntry {
                return EntryRow( prefix: state.stack[regX].prefix, register: state.entryText, exponent: "\(state.exponentText)_")
            }
            else {
                return EntryRow( prefix: state.stack[regX].prefix, register: "\(state.entryText)_")
            }
        }
        return state.stack[ stkIndex ]
    }
    
    func memoryOp( key: KeyCode, index: Int ) {
        undoStack.push(state)
        acceptTextEntry()

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
        acceptTextEntry()
        undoStack.push(state)
        state.memory.append( NamedValue( value: state.Xtv) )
    }
    
    func delMemoryItems( set: IndexSet) {
        cancelTextEntry()
        undoStack.push(state)
        state.memory.remove( atOffsets: set )
    }
    
    func renameMemoryItem( index: Int, newName: String ) {
        cancelTextEntry()
        undoStack.push(state)
        state.memory[index].name = newName
    }
    
    class UnaryOp: StateOperator {
        let function: (Double) -> Double
        
        init(_ function: @escaping (Double) -> Double ) {
            self.function = function
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            var s1 = s0
            s1.X = function( s0.X )
            return s1
        }
    }
    
    class BinaryOpReal: StateOperator {
        let function: (Double, Double) -> Double
        
        init(_ function: @escaping (Double, Double) -> Double ) {
            self.function = function
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            if s0.Yt.code != .untyped || s0.Xt.code != .untyped {
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
            if s0.Yt.code == .untyped && s0.Xt.code != .untyped {
                // Cannot convert X operand back to untyped
                return nil
            }
            
            // Result will be same type as Y
            var s1 = s0
            s1.stackDrop()

            if s0.Yt == s0.Xt {
                // Identical types
                s1.X = function( s0.Y, s0.X )
            }
            else if
                let xType = TypeFinancial.getRecord( s0.Xt ),
                let yType = TypeFinancial.getRecord( s0.Yt ) {
                    // Convert X value to type Y
                    s1.X = function( s0.Y, s0.X * xType.usd / yType.usd )
                }
            else {
                return nil
            }
            return s1
        }
    }
    
    class BinaryOpMultiplicative: StateOperator {
        let function: (Double, Double) -> Double
        
        init(_ function: @escaping (Double, Double) -> Double ) {
            self.function = function
        }
        
        func transition(_ s0: CalcState ) -> CalcState? {
            guard s0.Xt.code == .untyped else {
                // X operand must be an untyped value
                return nil
            }
            // Ressult will be same type as Y
            var s1 = s0
            s1.stackDrop()
            s1.X = function( s0.Y, s0.X )
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
    
    let opTable: [KeyCode : StateOperator] = [
        .plus:  BinaryOpAdditive( + ),
        .minus: BinaryOpAdditive( - ),
        .times: BinaryOpMultiplicative( * ),
        
        // Square root, inverse, x squared, y to the x
        .sqrt:  UnaryOp( sqrt ),
        .inv:   UnaryOp( { (x: Double) -> Double in return 1.0/x } ),
        .x2:    UnaryOp( { (x: Double) -> Double in return x*x } ),
        .y2x:   BinaryOpReal( pow ),
        
        // Math function row 0
        .sin:   UnaryOp( sin ),
        .cos:   UnaryOp( cos ),
        .tan:   UnaryOp( tan ),
        .log:   UnaryOp( log10 ),
        .ln:    UnaryOp( log ),
        .pi:    UnaryOp( { (_) -> Double in return Double.pi } ),

        .divide:
            CustomOp { s0 in
                var s1 = s0
                s1.stackDrop()
                
                if s0.Yt == s0.Xt {
                    // Identical types produces untyped result
                    s1.X = s0.Y / s0.X
                    s1.Xt = TypeTag(.untyped, 0)
                }
                else if s0.Xt.code == .untyped {
                    s1.X = s0.Y / s0.X
                    s1.Xt = s0.Yt
                }
                else if
                    let xType = TypeFinancial.getRecord( s0.Xt ),
                    let yType = TypeFinancial.getRecord( s0.Yt ) {
                        // Convert X value to type Y
                        s1.X = s0.Y / (s0.X * xType.usd / yType.usd)
                        s1.Xt = TypeTag(.untyped, 0)
                }
                else {
                    return nil
                }
                return s1
            },
        
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
            }
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
                    state.exponentText.append( String(keyCode.rawValue))
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
                state.entryText.append( String(keyCode.rawValue))
                
            case .dot:
                if !state.decimalSeen {
                    state.entryText.append(".")
                    state.decimalSeen = true
                }
                
            case .eex:
                if !state.decimalSeen {
                    state.entryText += ".0"
                    state.decimalSeen = true
                }
                state.entryText += "×10"
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
                if state.entryText.removeLast() == "." {
                    state.decimalSeen = false
                }
                
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
        let (padCode, keyCode) = event
        
        if state.entryMode && EntryModeKeypress(keyCode) {
            return
        }
        
        if padCode == .padFiat {
            acceptTextEntry()
            financialKeyPress( TypeTag(.fiat, keyCode.rawValue - KeyCode.sk0.rawValue) )
            return
        }
        
        switch keyCode {
        case .key0, .key1, .key2, .key3, .key4, .key5, .key6, .key7, .key8, .key9:
            startTextEntry( String(keyCode.rawValue) )
            state.stackLift()
            break
            
        case .dot:
            startTextEntry( "0." )
            state.stackLift()
            break
            
        case .back:
            // Undo last operation by restoring previous state
            if let lastState = undoStack.pop() {
                state = lastState
            }
            break
            
        case .fixL:
            var trec = getRecord( state.Xt )
            trec.digits = max(0, trec.digits-1 )
            break
            
        case .fixR:
            var trec = getRecord( state.Xt )
            trec.digits = min(15, trec.digits+1 )
            break
            
        default:
            if let op = opTable[keyCode] {
                // Transition to new calculator state based on operation
                undoStack.push(state)
                acceptTextEntry()
                if let newState = op.transition( state ) {
                    state = newState
                }
                else {
                    // else no-op as there was no new state
                    if let lastState = undoStack.pop() {
                        state = lastState
                    }
                }
            }
            break
        }
    }
}

extension Double {
    var fixedFormat: String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 4
        nf.maximumFractionDigits = 4
        return nf.string(from: NSNumber(value: self)) ?? ""
    }

    func displayFormat(_ digits: Int, _ minDigits: Int ) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = minDigits
        nf.maximumFractionDigits = digits
        return nf.string(from: NSNumber(value: self)) ?? ""
    }
}


