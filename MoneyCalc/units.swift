//
//  units.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2024-09-03.
//

import Foundation

enum UnitId: Int {
    case none = 0, untyped, angle, length, area, volume, velocity, acceleration, time
    case mass, weight, pressure, capacity, temp
    case user = 100
}

let unitX:Int = 1000

typealias TypeId = Int

struct TypeTag: Hashable {
    var uid : UnitId
    var tid : TypeId
    
    func isType( _ uid: UnitId ) -> Bool {
        return self.uid == uid
    }
    
    var symbol: String? {
        if let def = TypeDef.typeDict[self] {
            // Get symbol from definition
            return def.symbol
        }
        else if uid == .untyped {
            return nil
        }
        else {
            // or return unit name and type offset
            return "<\(String(describing: uid)):\(tid % unitX)>"
        }
    }
    
    init( _ uid: UnitId, _ tid: TypeId = 0 ) {
        self.uid = uid
        self.tid = tid == 0 ? uid.rawValue * unitX : tid
    }
}


typealias UnitCode = [(UnitId, Int)]
typealias TypeCode = [(TypeTag, Int)]

typealias UnitSignature = String
typealias TypeSignature = String


func toUnitCode( from: UnitSignature ) -> UnitCode {
    ///
    /// UnitSignature -> UnitCode
    ///
    var uc: UnitCode = []
    
    if ( from.isEmpty ) {
        return uc
    }
    
    let pn = from.split( separator: "/")
    
    let pstr = pn[0]
    let nstr = pn.count > 1 ? pn[1] : ""
    
    let pFactors = pstr.split( separator: "*")
    
    for pf in pFactors {
        let bits = pf.split( separator: "^")
       
        if let unit = UnitDef.symDict[ String(bits[0]) ] {
            let exp: Int = bits.count > 1 ? Int(bits[1])! : 1
            uc.append( (unit.uid, exp) )
        }
    }
    
    if !nstr.isEmpty {
        let nFactors = nstr.split( separator: "*")
        
        for nf in nFactors {
            let bits = nf.split( separator: "^")
            
            if let unit = UnitDef.symDict[ String(bits[0]) ] {
                let exp: Int = bits.count > 1 ? Int(bits[1])! : 1
                uc.append( (unit.uid, -exp) )
            }
        }
    }

    return uc
}


func toTypeCode( from: TypeSignature ) -> TypeCode {
    ///
    ///  TypeSignature -> TypeCode
    ///
    var tc: TypeCode = []
    
    if ( from.isEmpty ) {
        return tc
    }
    
    let pn = from.split( separator: "/")
    
    let pstr = pn[0]
    let nstr = pn.count > 1 ? pn[1] : ""
    
    let pFactors = pstr.split( separator: "*")
    
    for pf in pFactors {
        let bits = pf.split( separator: "^")
       
        if let tag = TypeDef.symDict[ String(bits[0]) ] {
            let exp: Int = bits.count > 1 ? Int(bits[1])! : 1
            tc.append( (tag, exp) )
        }
    }
    
    if !nstr.isEmpty {
        let nFactors = nstr.split( separator: "*")
        
        for nf in nFactors {
            let bits = nf.split( separator: "^")
            
            if let tag = TypeDef.symDict[ String(bits[0]) ] {
                let exp: Int = bits.count > 1 ? Int(bits[1])! : 1
                tc.append( (tag, -exp) )
            }
        }
    }

    return tc
}


class UnitDef {
    var uid:    UnitId
    var uc:     UnitCode
    var sym:    String
    var list:   [TypeDef] = []
    
    init( _ uid: UnitId, _ us: UnitSignature?, _ sym: String? ) {
        self.uid = uid
        
        if let str = sym {
            self.sym = str
        }
        else {
            self.sym = String( describing: uid)
        }
        
        if let usig = us {
            self.uc = toUnitCode( from: usig )
        }
        else {
            self.uc = [(uid, 1)]
        }
        
        UnitDef.symDict[self.sym] = self
    }
    
    static var unitDict: [UnitId : UnitDef] = [:]
    static var symDict:  [String : UnitDef] = [:]
    static var sigDict:  [UnitSignature : UnitDef] = [:]
}

#if DEBUG
extension UnitDef: CustomStringConvertible {
    var description: String {
        return "<\(sym):[\(getUnitSig(uc))]:list[\(list.count)]>"
    }
}
#endif




class TypeDef {
    var uid:   UnitId
    var tc:    TypeCode
    var sym:   String?
    var ratio: Double
    var delta: Double
    var tid:   TypeId
    
    init( _ uid: UnitId, _ sym: String, _ ratio: Double, delta: Double = 0.0 ) {
        self.uid = uid
        self.sym = sym
        self.ratio = ratio
        self.delta = delta
        self.tid = uid.rawValue * unitX
        self.tc = [(TypeTag(uid, tid), 1)]
    }

    init( _ uid: UnitId, tsig: TypeSignature, _ ratio: Double, delta: Double = 0.0 ) {
        self.uid = uid
        self.ratio = ratio
        self.delta = delta
        self.tid = uid.rawValue * unitX
        self.tc = toTypeCode( from: tsig)
    }
    
    var symbol: String {
        if let str = self.sym {
            return str
        }
        else {
            return getTypeSig(self.tc)
        }
    }
    
    static var typeDict: [TypeTag : TypeDef] = [:]
    static var symDict:  [String : TypeTag] = [:]
    static var sigDict:  [TypeSignature : TypeTag] = [:]

    
    static func defineUnit( _ uid: UnitId, _ usig: UnitSignature? = nil, _ name: String? = nil ) {
        let def = UnitDef( uid, usig, name)
        
        UnitDef.unitDict[uid] = def
        
        if let sig = usig {
            UnitDef.sigDict[sig] = def
        }
    }
    
    static func defineType( _ uid: UnitId, _ sym: String, _ ratio: Double, delta: Double = 0.0 ) {
        let def = TypeDef(uid, sym, ratio, delta: delta)
        
        if let unit = UnitDef.unitDict[uid] {
            def.tid += unit.list.count
            unit.list.append(def)
        }
        
        let tag = TypeTag(uid, def.tid)
        TypeDef.typeDict[tag] = def
        TypeDef.symDict[sym] = tag
    }

    static func defineType( _ uid: UnitId, tsig: TypeSignature, _ ratio: Double, delta: Double = 0.0 ) {
        let def = TypeDef(uid, tsig: tsig, ratio, delta: delta)
        
        if let unit = UnitDef.unitDict[uid] {
            def.tid += unit.list.count
            unit.list.append(def)
        }
        
        let tag = TypeTag(uid, def.tid)
        TypeDef.typeDict[tag] = def
        TypeDef.sigDict[tsig] = tag
    }
    
    
    static func buildUnitData() {
        defineUnit( .time )
        defineUnit( .mass )
        defineUnit( .temp )
        defineUnit( .angle )
        defineUnit( .length )
        defineUnit( .weight )
        defineUnit( .capacity )
        defineUnit( .area, "length^2" )
        defineUnit( .volume, "length^3" )
        defineUnit( .velocity, "length/time" )
        defineUnit( .acceleration, "length/time^2" )
        defineUnit( .pressure, "weight/length^2" )
        
        defineType( .length,   "m",    1)
        defineType( .length,   "mm",   1000)
        defineType( .length,   "cm",   100)
        defineType( .length,   "km",   0.001)

        defineType( .angle,    "rad",  1)
        defineType( .angle,    "deg",  180/Double.pi)

        defineType( .time,     "sec",  1)
        defineType( .time,     "min",  1/60.0)
        defineType( .time,     "hr",   1/3600.0)
        defineType( .time,     "day",  1/86400.0)
        defineType( .time,     "yr",   1/31536000.0)

        defineType( .mass,     "g",    1)
        defineType( .mass,     "kg",   0.001)
        defineType( .mass,     "mg",   1000)
        defineType( .mass,     "tonne",0.000001)
        defineType( .mass,     "g",    1)

        defineType( .weight,   "lb",   1)
        defineType( .weight,   "oz",   16.0)
        defineType( .weight,   "ton",  1/2000.0)

        defineType( .temp,     "C",    1.0)
        defineType( .temp,     "F",    9.0/5.0, delta: 32)

        defineType( .velocity,  tsig: "m/sec",  1.0)
        
        #if DEBUG
        // UnitDef
        print( "Unit Definitions:")
        for (uid, def) in UnitDef.unitDict {
            print( "'\(uid)' - > \(def)" )
        }
        print( "\nType Definitions:")
        for (tt, def) in TypeDef.typeDict {
            print( "\(tt) -> \(def)")
        }
        #endif
    }
}


#if DEBUG
extension TypeTag: CustomStringConvertible {
    var description: String {
        return "\(String(describing: uid)):\(tid)"
    }
}


extension TypeDef: CustomStringConvertible {
    var description: String {
        return "<\(String(describing: uid)):\(String( describing: sym)) tid:\(tid)>"
    }
}
#endif


func normalizeUnitCode( _ uc: inout UnitCode ) {
    
    uc.sort { (xUC, yUC) in
        let (xUid, xExp) = xUC
        let (yUid, yExp) = yUC
        
        if xExp*yExp < 0 {
            return xExp > yExp
        }
        
        return xUid.rawValue < yUid.rawValue
    }
}


func normalizedUC( _ uc: UnitCode ) -> UnitCode {
    var ucV = uc
    normalizeUnitCode(&ucV)
    return ucV
}


func normalizeTypeCode( _ tc: inout TypeCode ) {
    
    tc.sort { (xTC, yTC) in
        let (xTT, xExp) = xTC
        let (yTT, yExp) = yTC
        
        if xExp*yExp < 0 {
            return xExp > yExp
        }
        
        return xTT.uid.rawValue < yTT.uid.rawValue
    }
}


func getUnitSig( _ uc: UnitCode ) -> UnitSignature {
    ///
    /// UnitCode -> UnitSignature
    ///
    let (_, exp0) = uc[0]
    var ss = exp0 < 0 ? "1/" : ""
    var negSeen: Bool = false
    var fn = 0

    for (uid, exp) in uc {
        
        if fn > 0 {
            if exp < 0 && !negSeen {
                ss.append("/")
                negSeen = true
            }
            else {
                ss.append( "*" )
            }
        }
        
        ss.append( String( describing: uid) )
        
        if abs(exp) > 1 {
            ss.append( "^\(abs(exp))" )
        }
        fn += 1
    }
    return ss
}


func getTypeSig( _ tc: TypeCode ) -> TypeSignature {
    ///
    ///  TypeCode -> TypeSignature
    ///
    let (_, exp0) = tc[0]
    var ss = exp0 < 0 ? "1/" : ""
    var negSeen: Bool = false
    var fn = 0

    for (tt, exp) in tc {
        
        if fn > 0 {
            if exp < 0 && !negSeen {
                ss.append("/")
                negSeen = true
            }
            else {
                ss.append( "*" )
            }
        }
        
        if let def = TypeDef.typeDict[tt],
           let sym = def.sym
        {
            ss.append( sym )
        }
        else {
            ss.append( "\(String(describing: tt.uid)):\(tt.tid % unitX)" )
        }
        
        if abs(exp) > 1 {
            ss.append( "^\(abs(exp))" )
        }
        fn += 1
    }
    return ss
}


func toUnitCode( from: TypeCode ) -> UnitCode {
    ///
    /// TypeCode -> UnitCode
    ///
    return from.map( { (tag, exp) in (tag.uid, exp) } )
}


protocol ConversionOp {
    func op( _ x: Double ) -> Double
    
    func opRev( _ x: Double ) -> Double
}

struct OffsetOp : ConversionOp {
    let offset: Double
    
    init( _ offset: Double ) {
        self.offset = offset
    }
    
    func op( _ x: Double ) -> Double {
        return x + offset
    }
    
    func opRev( _ x: Double ) -> Double {
        return x - offset
    }
}

struct ScaleOp : ConversionOp {
    let scale: Double
    
    init( _ scale: Double ) {
        self.scale = scale
    }
    
    func op( _ x: Double ) -> Double {
        return x * scale
    }
    
    func opRev( _ x: Double ) -> Double {
        return x / scale
    }
}

struct ConversionSeq : ConversionOp {
    var opSeq: [ConversionOp]
    
    init( _ seq: [ConversionOp] ) {
        self.opSeq = seq
    }
    
    init( _ ratio: Double ) {
        self.opSeq = [ ScaleOp(ratio) ]
    }
    
    func op( _ x: Double ) -> Double {
        var y = x
        for s in opSeq {
            y = s.op(y)
        }
        return y
    }

    func opRev( _ x: Double ) -> Double {
        var y = x
        for s in opSeq.reversed() {
            y = s.opRev(y)
        }
        return y
    }
}


func unitConvert( from: TypeTag, to: TypeTag ) -> ConversionSeq? {
    if from.uid == .untyped {
        // An untyped value can convert to anything - no change in value
        return ConversionSeq(1.0)
    }
    
    if from.uid != to.uid {
        // Cannot convert incompatible units like angles and areas
        return nil
    }
    
    if let defF = TypeDef.typeDict[from],
       let defT = TypeDef.typeDict[to]
    {
        return ConversionSeq( defT.ratio / defF.ratio )
    }
    
    // Failed to find definitions for both types, conversion not possible
    return nil
}


func typeProduct( _ tagA: TypeTag, _ tagB: TypeTag, quotient: Bool = false ) -> TypeCode? {
    /// typeProduct( )
    /// Produce type code of product A*B or quotient A/B
    ///
    if let defA = TypeDef.typeDict[tagA],
       let defB = TypeDef.typeDict[tagB]
    {
        // Obtain type code sequences for both operands
        let tcA = defA.tc
        var tcB = defB.tc
        
        var tcQ: TypeCode = []
        
        let sign: Int = quotient ? -1 : 1
        
        for (ttA, expA) in tcA {
            if let x = tcB.firstIndex( where: { (ttB, expB) in ttB == ttA } ) {
                let (ttB, expB) = tcB[x]
                tcQ.append( (ttA, expA + sign*expB) )
                tcB.remove(at: x)
            }
            else {
                tcQ.append( (ttA, expA) )
            }
        }
        
        // Append remaining elements of B
        for (tagB, expB) in tcB {
            tcQ.append( (tagB, sign*expB) )
        }
        
        normalizeTypeCode(&tcQ)
        return tcQ
        
    }
    return  nil
}


func lookupTypeTag( _ tc: TypeCode ) -> TypeTag? {
    let tsig = getTypeSig(tc)
    
    if let tag = TypeDef.sigDict[tsig] {
        return tag
    }
    else {
        let uc = toUnitCode( from: tc )
        let usig = getUnitSig(uc)
        
        if let unit = UnitDef.sigDict[usig] {
            
            TypeDef.defineType(unit.uid, tsig: tsig, 1.0)
            
            if let tag = TypeDef.sigDict[tsig] {
                return tag
            }
        }
        else {
            TypeDef.defineUnit(.user, usig)
            
            TypeDef.defineType(.user, tsig: tsig, 1.0)
            
            if let tag = TypeDef.sigDict[tsig] {
                return tag
            }
        }
        
        return nil
    }
}


// Common tag values
let tagNone: TypeTag = TypeTag(.none)
let tagUntyped: TypeTag = TypeTag(.untyped)

let tagRad = TypeTag(.angle, 2000)
