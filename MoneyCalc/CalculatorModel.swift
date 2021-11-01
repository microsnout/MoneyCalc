//
//  CalculatorModel.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import Foundation

class CalculatorModel: ObservableObject, KeyPressHandler {
    // Register stack
    static let stackPrefixValues = ["X:", "Y:", "Z:", "T:"]
    static let stackSize = stackPrefixValues.count
    let regX = 0, regY = 1, regZ = 2, regT = 3

    private var registers: [Double] = Array( repeating: 0.0, count: stackSize)

    // Display window into register stack
    static let displayRows = 4

    // Display buffer
    @Published var buffer: [DisplayRow] = stackPrefixValues.prefix(displayRows).reversed().map {
        DisplayRow( prefix: $0, register: 0.0.fixedFormat)
    }
    
    func bufferIndex(_ stackIndex: Int ) -> Int {
        return CalculatorModel.displayRows - stackIndex - 1
    }
    
    func getReg(_ index: Int ) -> Double {
        return registers[index]
    }
    
    func putReg(_ index: Int, _ newValue: Double ) {
        registers[index] = newValue
        
        if index < CalculatorModel.displayRows {
            buffer[ bufferIndex(index)].register = newValue.fixedFormat
        }
    }
    
    func copyReg(_ from: Int, to: Int ) {
        putReg(to,  getReg(from))
    }
    
    func clearReg(_ index: Int ) {
        putReg(index, 0.0)
    }
    
    func stackLift() {
        for rx in stride( from: CalculatorModel.stackSize-1, to: regX, by: -1 ) {
            copyReg(rx-1, to: rx)
        }
    }
    
    func stackDrop() {
        for rx in regX ..< CalculatorModel.stackSize-1 {
            copyReg(rx+1, to: rx)
        }
    }
    
    var enterMode: Bool = false;
    var enterText: String = ""
    
    private let entryKeys:Set<KeyID> = [.key0, .key1, .key2, .key3, .key4, .key5, .key6, .key7, .key8, .key9, .dot, .back]
    
    func keyPress( id: KeyID) {
        
        if enterMode {
            if entryKeys.contains(id) {
                if id == .dot {
                    // Decimal is a no-op if one has already been entered
                    if !enterText.contains(".") { enterText.append(".")}
                }
                else if id == .back {
                    enterText.removeLast()
                    
                    if enterText.isEmpty {
                        // Clear X, exit entry mode, no further actions
                        clearReg(regX)
                        enterMode = false
                        return
                    }
                }
                else {
                    enterText.append( String( id.rawValue))
                }
                buffer[ bufferIndex(regX)].register = "\(enterText)_"
                return
            }
            else {
                putReg(regX, Double(enterText)! )
                enterMode = false
                // Fallthrough to switch
            }
        }
        
        switch id {
        case .key0, .key1, .key2, .key3, .key4, .key5, .key6, .key7, .key8, .key9:
            enterText = String(id.rawValue)
            stackLift()
            buffer[ bufferIndex(regX)].register = "\(enterText)_"
            enterMode = true
            break
            
        case .dot:
            enterText = "0."
            enterMode = true
            stackLift()
            buffer[ bufferIndex(regX)].register = "\(enterText)_"
            break
            
        case .enter:
            stackLift()
            break
            
        case .clear:
            clearReg(regX)
            break
            
        case .plus:
            let result = getReg(regX) + getReg(regY)
            stackDrop()
            putReg(regX, result)
            break
            
        case .minus:
            let result = getReg(regY) - getReg(regX)
            stackDrop()
            putReg(regX, result)
            break
            
        case .times:
            let result = getReg(regX) * getReg(regY)
            stackDrop()
            putReg(regX, result)
            break
            
        case .divide:
            let result = getReg(regY) / getReg(regX)
            stackDrop()
            putReg(regX, result)
            break
            
        default:
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
}


