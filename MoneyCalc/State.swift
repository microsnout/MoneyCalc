//
//  State.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2024-09-28.
//

import Foundation
import Numerics
import OSLog

let logS = Logger(subsystem: "com.microsnout.calculator", category: "state")


// Standard HP calculator registers
let stackPrefixValues = ["X", "Y", "Z", "T"]

// Register index values
let regX = 0, regY = 1, regZ = 2, regT = 3, stackSize = 4

typealias FormatMode = NumberFormatter.Style

struct FormatRec {
    var mode: FormatMode = .decimal
    var digits: Int = 4
    var minDigits: Int = 0
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
    /// Defines the exact state of the calculator at a given time
    ///
    var stack: [NamedValue] = stackPrefixValues.map { NamedValue( $0, value: untypedZero) }
    var lastX: TaggedValue = untypedZero
    var noLift: Bool = false
    var memory = [NamedValue]()
    
    static let defaultFormat: FormatRec = FormatRec( mode: .decimal, digits: 4 )
    static let defaultSciFormat: FormatRec = FormatRec( mode: .scientific, digits: 4 )
    static let defaultPercentFormat: FormatRec = FormatRec( mode: .percent, digits: 2 )
    static let defaultCurrencyFormat: FormatRec = FormatRec( mode: .currency, digits: 2, minDigits: 2 )

    // Data entry state
    var entryMode: Bool = false
    var exponentEntry: Bool = false
    var decimalSeen: Bool = false
    var negativeSign: Bool = false
    var digitCount: Int = 0
    var entryText: String = ""
    var exponentText: String = ""
    
    let digits: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    
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
        nf.minimumFractionDigits = fmt.minDigits
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
    
    // *** Data Entry Functions ***
    
    mutating func clearEntry() {
        entryMode = false
        exponentEntry = false
        decimalSeen = false
        negativeSign = false
        digitCount = 0
        entryText.removeAll(keepingCapacity: true)
        exponentText.removeAll(keepingCapacity: true)
        
        logM.debug( "ClearEntry" )
    }

    mutating func startTextEntry(_ str: String ) {
        clearEntry()
        entryMode = true
        entryText = str
        digitCount = 1
        decimalSeen = entryText.contains(".")
        
        logM.debug("StartTextEntry: \(str)")
    }
    
    mutating func startExpEntry() {
        appendTextEntry("×10")
        exponentText = ""
        exponentEntry = true
    }
    
    mutating func flipTextSign() {
        if entryText.starts( with: "-") {
            entryText.removeFirst()
            negativeSign = false
        }
        else {
            entryText.insert( "-", at: entryText.startIndex )
            negativeSign = true
        }
    }
    
    mutating func recommaEntry() {
        // Func is a noop if data entry contains a decimal point
        if !decimalSeen {
            if negativeSign {
                // Temporarily remove the negative sign
                entryText.removeFirst()
            }
            
            // Remove all commas
            entryText.removeAll( where: { $0 == "," })
            
            if digitCount > 3 {
                // Work with string as array
                var seq = Array(entryText)
                
                let commaCount = (digitCount - 1) / 3
                
                for ix in 1...commaCount {
                    seq.insert(",", at: (digitCount-1) % 3 + 1 + (ix-1)*4 )
                }
                
                // restore the data string from array
                entryText = String(seq)
            }
            
            if negativeSign {
                // reinsert the negative sign if required
                entryText.insert( "-", at: entryText.startIndex )
            }
        }
    }
    
    mutating func appendTextEntry(_ str: String ) {
        if str == "." {
            if !decimalSeen {
                entryText += str
                decimalSeen = true
            }
        }
        else if digits.contains(str) {
            entryText += str
            digitCount += 1
            recommaEntry()
        }
        else {
            entryText += str
        }
        
        let txt = self.entryText
        logM.debug( "AppendTextEntry: '\(str)' -> '\(txt)'")
    }
    
    mutating func appendExpEntry(_ str: String ) {
        self.exponentText += str
        
        let txt = self.exponentText
        logM.debug( "AppendExponentEntry: '\(str)' -> '\(txt)'")
    }
    
    mutating func backspaceEntry() {
        if !entryText.isEmpty {
            let ch = entryText.removeLast()
            
            if ch == "." {
                decimalSeen = false
            }
            else if digits.contains(ch) {
                digitCount -= 1
                recommaEntry()
            }
            
            if entryText.isEmpty || entryText == "-" {
                clearEntry()
            }
        }
    }
    
    mutating func acceptTextEntry() {
        if entryMode {
            var num: String = entryText
            
            logM.debug( "AcceptTextEntry: \(num)")
            
            if exponentEntry {
                /// Eliminate 'x10'
                num.removeLast(3)
            }
            
            // Remove all commas
            num.removeAll( where: { $0 == "," })

            if exponentEntry && !exponentText.isEmpty {
                /// Exponential entered
                let str: String = num + "E" + exponentText
                stack[regX].value.reg = Double(str)!
                stack[regX].value.tag = tagUntyped
                stack[regX].value.fmt = CalcState.defaultSciFormat
            }
            else {
                stack[regX].value.reg = Double(num)!
                stack[regX].value.tag = tagUntyped
                stack[regX].value.fmt = CalcState.defaultFormat
            }
            clearEntry()
        }
    }
    
    // *** *** ***

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
    
    var Yfmt: FormatRec {
        get { stack[regY].value.fmt }
        set { stack[regY].value.fmt = newValue }
    }
    
    var Ytv: TaggedValue {
        get { stack[regY].value }
        set { self.Yt = newValue.tag; self.Y = newValue.reg; self.Yfmt = newValue.fmt }
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
