//
//  MoneyCalcApp.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import SwiftUI

@main
struct MoneyCalcApp: App {
    init () {
        TypeDef.buildUnitData()
    }
    
    var body: some Scene {
        WindowGroup {
            CalculatorView()
        }
    }
}
