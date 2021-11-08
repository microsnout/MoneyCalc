//
//  CalculatorModel.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import Foundation

let stackPrefixValues = ["X", "Y", "Z", "T"]

let regX = 0, regY = 1, regZ = 2, regT = 3, stackSize = 4

enum TypeClass: Int {
    case untyped = 0, percentage, fiat, crypto, shares, time, compound
}

typealias TypeIndex = Int

typealias TypeTag = ( class: TypeClass, index: TypeIndex)

protocol TypeRecord {
    var suffix: String { get }
}

class TypeUntyped: TypeRecord {
    var suffix: String { "" }
}

class TypePercentage: TypeRecord {
    var suffix: String { "%" }
}

 func getRecord(_ tag: TypeTag ) -> TypeRecord {
    
    switch tag.class {
    case .untyped:
        return TypeUntyped()
    case .percentage:
        return TypePercentage()
        
    case .crypto, .fiat:
        if let rec = TypeFinancial.getRecord(tag) {
            return rec
        }
        return TypeUntyped()

    default:
        return TypeUntyped()
    }
}


struct CalcState {
    var stack: [Double] = Array( repeating: 0.0, count: stackSize)
    var tags: [TypeTag] = Array( repeating: (.untyped, 0), count: stackSize)
    var lastX: Double = 0.0
    var noLift: Bool = false
    
    var X: Double {
        get { stack[regX] }
        set { stack[regX] = newValue }
    }
    
    var Xt: TypeTag {
        get { tags[regX] }
        set { tags[regX] = newValue }
    }
    
    var Y: Double {
        get { stack[regY] }
        set { stack[regY] = newValue }
    }
    
    var Z: Double {
        get { stack[regZ] }
        set { stack[regZ] = newValue }
    }
    
    var T: Double {
        get { stack[regT] }
        set { stack[regT] = newValue }
    }
    
    mutating func stackDrop(_ by: Int = 1 ) {
        for rx in regX ..< stackSize-1 {
            self.stack[rx] = self.stack[rx+1]
            self.tags[rx] = self.tags[rx+1]
        }
    }

    mutating func stackLift(_ by: Int = 1 ) {
        for rx in stride( from: stackSize-1, to: regX, by: -1 ) {
            self.stack[rx] = self.stack[rx-1]
            self.tags[rx] = self.tags[rx-1]
        }
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
    func transition(_ s0: CalcState ) -> CalcState
}


class CalculatorModel: ObservableObject, KeyPressHandler {
    // Current Calculator State
    var state = CalcState()
    var undoStack = UndoStack()

    // Display window into register stack
    static let displayRows = 4

    // Display buffer
    @Published var buffer: [DisplayRow] = stackPrefixValues.prefix(displayRows).reversed().map {
        DisplayRow( prefix: $0, register: 0.0.fixedFormat)
    }

    // Numeric entry occurs on X register
    private var enterMode: Bool = false;
    private var enterText: String = ""
    
    private let entryKeys:Set<Int> = [key0, key1, key2, key3, key4, key5, key6, key7, key8, key9, dot, back]
    
    func bufferIndex(_ stackIndex: Int ) -> Int {
        return CalculatorModel.displayRows - stackIndex - 1
    }
    
    func updateDisplay() {
        for rx in (enterMode ? regY : regX) ... regT {
            buffer[ bufferIndex(rx) ].register = state.stack[rx].fixedFormat
            
            let typeRec = getRecord( state.tags[rx] )
            buffer[ bufferIndex(rx) ].suffix = typeRec.suffix
        }
        if enterMode {
            buffer[ bufferIndex(regX)].register = "\(enterText)_"
            buffer[ bufferIndex(regX)].suffix = ""
        }
    }
    
    class UnaryOp: StateOperator {
        let function: (Double) -> Double
        
        init(_ function: @escaping (Double) -> Double ) {
            self.function = function
        }
        
        func transition(_ s0: CalcState ) -> CalcState {
            var s1 = s0
            s1.X = function( s0.X )
            return s1
        }
    }
    
    class BinaryOp: StateOperator {
        let function: (Double, Double) -> Double
        
        init(_ function: @escaping (Double, Double) -> Double ) {
            self.function = function
        }
        
        func transition(_ s0: CalcState ) -> CalcState {
            var s1 = s0
            s1.stackDrop()
            s1.X = function( s0.Y, s0.X )
            return s1
        }
    }
    
    class CustomOp: StateOperator {
        let block: (CalcState) -> CalcState
        
        init(_ block: @escaping (CalcState) -> CalcState ) {
            self.block = block
        }
        
        func transition(_ s0: CalcState ) -> CalcState {
            return block(s0)
        }
    }
    
    let opTable: [KeyID: StateOperator] = [
        plus:      BinaryOp( + ),
        minus:     BinaryOp( - ),
        times:     BinaryOp( * ),
        divide:    BinaryOp( / ),
        enter:
            CustomOp { s0 in
                var s1 = s0
                s1.stackLift()
                s1.noLift = true
                return s1
            },
        clear:
            CustomOp { s0 in
                var s1 = s0
                s1.X = 0.0
                s1.Xt = (.untyped, 0)
                s1.noLift = true
                return s1
            }
    ]
    
    func keyPress(_ event: KeyEvent) {
        let (padID, keyID) = event
        
        if enterMode {
            if entryKeys.contains(keyID) {
                if keyID == dot {
                    // Decimal is a no-op if one has already been entered
                    if !enterText.contains(".") { enterText.append(".")}
                }
                else if keyID == back {
                    enterText.removeLast()
                    
                    if enterText.isEmpty {
                        // Clear X, exit entry mode, no further actions
                        state.noLift = true
                        enterMode = false
                    }
                }
                else {
                    enterText.append( String(keyID))
                }
                
                updateDisplay()
                return
            }
                
            state.stack[regX] = Double(enterText)!
            state.tags[regX] = (.untyped, 0)
            enterMode = false
            // Fallthrough to switch
        }
        
        if padID == rowCrypto {
            financialKeyPress( (.crypto, keyID - sk0) )
            updateDisplay()
            return
        }
        else if padID == rowFiat {
            financialKeyPress( (.fiat, keyID - sk0) )
            updateDisplay()
            return
        }
        
        switch keyID {
        case key0, key1, key2, key3, key4, key5, key6, key7, key8, key9:
            enterText = String(keyID)
            enterMode = true
            if !state.noLift {
                state.stackLift()
            }
            state .noLift = false
            break
            
        case dot:
            enterText = "0."
            enterMode = true
            if !state.noLift {
                state.stackLift()
            }
            state .noLift = false
            break
            
        case back:
            if let lastState = undoStack.pop() {
                state = lastState
            }
            break
            
        default:
            if let op = opTable[keyID] {
                let newState = op.transition( state )
                undoStack.push(state)
                state = newState
            }
            break
        }
        updateDisplay()
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
}


