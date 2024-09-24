//
//  units.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2024-09-03.
//

import Foundation
import OSLog

let logU = Logger(subsystem: "com.microsnout.calculator", category: "units")

// Standard predefined unit types, .user indicates dynamically defined new type
// UnitId value is Int equal to rawValue but can exceed .user
//
enum StdUnitId: Int {
    case none = 0, untyped, angle, length, area, volume, velocity, acceleration, time
    case mass, weight, pressure, capacity, temp
    case user = 1000
}

// Starting value for UnitIds of type .user
let userIdBase:Int = 1000

typealias UnitId = Int
typealias TypeId = Int


// Common UnitId values as Int
let uidNone = StdUnitId.none.rawValue
let uidUntyped = StdUnitId.untyped.rawValue
let uidUser = StdUnitId.user.rawValue


struct TypeTag: Hashable {
    var uid : UnitId
    var tid : TypeId
    
    func isType( _ uid: UnitId ) -> Bool {
        return self.uid == uid
    }
    
    func isType( _ uid: StdUnitId ) -> Bool {
        /// This func can determine if a tag is a specific predefined type or a user type but not which user type
        if uid == .user && self.uid >= userIdBase {
            return true
        }
        return self.uid == uid.rawValue
    }
    
    var symbol: String? {
        if let def = TypeDef.typeDict[self] {
            // Get symbol from definition
            return def.symbol
        }
        else if uid == uidUntyped {
            // Untyped numbers have no symbol
            return nil
        }
        else {
            // Unknown type
            return self.description
        }
    }
    
    init( _ uid: UnitId, _ tid: TypeId = 0 ) {
        self.uid = uid
        self.tid = tid
    }
    
    init( _ uid: StdUnitId, _ tid: TypeId = 0 ) {
        self.uid = uid.rawValue
        self.tid = tid
    }
}

extension TypeTag: CustomStringConvertible {
    var description: String {
        if self.isType(.user) {
            return "{User\(self.uid - userIdBase):\(self.tid)}"
        }
        return "{\(StdUnitId( rawValue: uid) ?? .none) :\(tid)}"
    }
}

func uid2Str( _ uid: UnitId ) -> String {
    if uid >= userIdBase {
        return "User\(uid - userIdBase)"
    }
    return "\(StdUnitId( rawValue: uid) ?? .none)"
}

extension String {
    init( uid: UnitId ) {
        self.init( uid2Str(uid))
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
    
    if ( from.isEmpty || from == "1" ) {
        return uc
    }
    
    // Positive Negative exponent parts
    let pn = from.split( separator: "/")
    
    // if count is 2 there is a list of negative exponent factors or denomenator units 'm/s' -> 'm', 's'
    let pstr = pn[0]
    let nstr = pn.count > 1 ? pn[1] : ""
    
    // Multipication symbol separated factors 'N·m'
    let pFactors = pstr.split( separator: "·")
    
    for pf in pFactors {
        // Exponent symbol is present if exp is not 1
        let bits = pf.split( separator: "^")
       
        if let unit = UnitDef.symDict[ String(bits[0]) ] {
            let exp: Int = bits.count > 1 ? Int(bits[1])! : 1
            uc.append( (unit.uid, exp) )
        }
    }
    
    if !nstr.isEmpty {
        // Same process for factors after the / except all exponents are negated
        let nFactors = nstr.split( separator: "·")
        
        for nf in nFactors {
            let bits = nf.split( separator: "^")
            let sym = String(bits[0])
            
            if let unit = UnitDef.symDict[sym] {
                let exp: Int = bits.count > 1 ? Int(bits[1])! : 1
                uc.append( (unit.uid, -exp) )
            }
            else {
                logU.error( "Undefined unit symbol: \(sym) in signature: \(from)" )
            }
        }
    }

    return uc
}


func getUnitSig( _ uc: UnitCode ) -> UnitSignature {
    ///
    /// UnitCode -> UnitSignature
    ///     [(length, 1),(time,-2)] -> "length/time^2"
    ///
    if uc.isEmpty {
        return ""
    }
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
                ss.append( "·" )
            }
        }
        
        ss.append( uid2Str(uid) )
        
        if abs(exp) > 1 {
            ss.append( "^\(abs(exp))" )
        }
        fn += 1
    }
    return ss
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
    
    let pFactors = pstr.split( separator: "·")
    
    for pf in pFactors {
        let bits = pf.split( separator: "^")
       
        if let tag = TypeDef.symDict[ String(bits[0]) ] {
            let exp: Int = bits.count > 1 ? Int(bits[1])! : 1
            tc.append( (tag, exp) )
        }
    }
    
    if !nstr.isEmpty {
        let nFactors = nstr.split( separator: "·")
        
        for nf in nFactors {
            let bits = nf.split( separator: "^")
            let sym = String(bits[0]) 
            
            if let tag = TypeDef.symDict[sym] {
                let exp: Int = bits.count > 1 ? Int(bits[1])! : 1
                tc.append( (tag, -exp) )
            }
            else {
                logU.error( "Undefined unit symbol: \(sym) in signature: \(from)" )
            }
        }
    }

    return tc
}


func getTypeSig( _ tc: TypeCode ) -> TypeSignature {
    ///
    ///  TypeCode -> TypeSignature
    ///
    if tc.isEmpty {
        return ""
    }
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
                ss.append( "·" )
            }
        }
        
        if let def = TypeDef.typeDict[tt],
           let sym = def.sym
        {
            ss.append( sym )
        }
        else {
            ss.append( "\(tt.description)" )
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
    ///     Reduce (km, 1) to (length, 1),   (sec, -2) to (time, -2)
    ///
    return from.map( { (tag, exp) in (tag.uid, exp) } )
}


class UnitDef {
    var uid:    UnitId
    var sym:    String?
    var uc:     UnitCode
    
    static var uidNext: UnitId = userIdBase
    
    static func getUserUnitId() -> UnitId {
        // Allocate new UnitId for type .user
        let uid = UnitDef.uidNext
        UnitDef.uidNext += 1
        return uid
    }
    
    init( _ uid: StdUnitId, sym: String, usig: UnitSignature? = nil ) {
        if uid == .user {
            // For defining unit definitions for standard predefined units only, not .user
            logU.error("Cannot define .user UnitDef without signature")
        }
        
        self.uid = uid.rawValue
        self.sym = sym
        
        if let sig = usig {
            self.uc = toUnitCode(from: sig)
        }
        else {
            self.uc = [(self.uid, 1)]
        }
    }
    
    init( _ usig: UnitSignature, sym: String? = nil ) {
        // Allocate new UnitId starting at .user, sym is optional, UnitCode produced from signature
        self.uid = UnitDef.getUserUnitId()
        self.sym = sym
        self.uc = toUnitCode( from: usig )
    }
    
    static var unitDict: [UnitId : UnitDef] = [:]
    static var symDict:  [String : UnitDef] = [:]
    static var sigDict:  [UnitSignature : UnitDef] = [:]

    static func defineUnit( _ uid: StdUnitId, _ usig: UnitSignature? = nil ) {
        let sym = String( describing: uid )
        let def = UnitDef( uid, sym: sym, usig: usig)

       // Add def to index by UnitId, Symbol and UnitSignature
        UnitDef.unitDict[uid.rawValue] = def
        UnitDef.symDict[sym] = def
        UnitDef.sigDict[ getUnitSig(def.uc)] = def
    }

    static func defineUserUnit( _ usig: UnitSignature, sym: String? = nil ) -> UnitDef {
        let def = UnitDef(usig, sym: sym)
        
        // Add def to index by UnitId, UnitSignature and Symbol if there is one
        UnitDef.unitDict[def.uid] = def
        UnitDef.sigDict[usig] = def
        if let symbol = sym {
            UnitDef.symDict[symbol] = def
        }
        return def
    }
}

#if DEBUG
extension UnitDef: CustomStringConvertible {
    var description: String {
        return "<\(uid2Str(self.uid)):\(String( describing: sym)):'\(getUnitSig(uc))'>"
    }
}
#endif


class TypeDef {
    var uid:   UnitId
    var tid:   TypeId
    var tc:    TypeCode
    var sym:   String?
    var ratio: Double
    var delta: Double
    
    static var tidNext: TypeId = 0
    
    static func getNewTid() -> TypeId {
        // Allocate next type id
        let tid = TypeDef.tidNext
        tidNext += 1
        return tid
    }
    
    init( _ uid: StdUnitId, sym: String, _ ratio: Double, delta: Double = 0.0 ) {
        self.uid = uid.rawValue
        self.tid = TypeDef.getNewTid()
        self.sym = sym
        self.ratio = ratio
        self.delta = delta
        self.tc = [(TypeTag(uid, tid), 1)]
    }

    init( _ uid: UnitId, tsig: TypeSignature ) {
        self.uid = uid
        self.tid = TypeDef.getNewTid()
        self.ratio = 1.0
        self.delta = 0
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
    
    static func defineType( _ uid: StdUnitId, _ sym: String, _ ratio: Double, delta: Double = 0.0 ) {
        if let unit = UnitDef.unitDict[uid.rawValue] {
            let def = TypeDef(uid, sym: sym, ratio, delta: delta)
            
            let tag = TypeTag(uid, def.tid)
            TypeDef.typeDict[tag] = def
            TypeDef.symDict[sym] = tag
        }
        else {
            logU.error("Cannot define type \(sym). UnitDef for uid \(uid2Str(uid.rawValue))")
        }
        
    }
    
    static func defineSigType( _ uid: UnitId, _ tsig: TypeSignature ) {
        let def = TypeDef(uid, tsig: tsig)
        let tag = TypeTag(def.uid, def.tid)
        TypeDef.typeDict[tag] = def
        TypeDef.sigDict[tsig] = tag
    }
    
    
    static func buildUnitData() {
        UnitDef.defineUnit( .time )
        UnitDef.defineUnit( .mass )
        UnitDef.defineUnit( .temp )
        UnitDef.defineUnit( .angle )
        UnitDef.defineUnit( .length )
        UnitDef.defineUnit( .weight )
        UnitDef.defineUnit( .capacity )
        UnitDef.defineUnit( .area, "length^2" )
        UnitDef.defineUnit( .volume, "length^3" )
        UnitDef.defineUnit( .velocity, "length/time" )
        UnitDef.defineUnit( .acceleration, "length/time^2" )
        UnitDef.defineUnit( .pressure, "weight/length^2" )
        
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
        
        return xUid < yUid
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
        
        return xTT.uid < yTT.uid
    }
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
    if from.uid == uidUntyped {
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


func typeProduct( _ tagA: TypeTag, _ tagB: TypeTag, quotient: Bool = false ) -> (TypeCode, Double)? {
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
        
        var ratio: Double = 1.0
        
        // For each unit factor in A
        for (ttA, expA) in tcA {
            if let x = tcB.firstIndex( where: { (ttB, expB) in ttB == ttA } ) {
                // There is a matching unit in B, combine the exponents and add to result if exp is nonzero
                let (_, expB) = tcB[x]
                let exp = expA + sign*expB
                if exp != 0 {
                    tcQ.append( (ttA, exp) )
                }
                tcB.remove(at: x)
            }
            else if let y = tcB.firstIndex ( where: { (ttB, expB) in ttB.uid == ttA.uid } ) {
                // A and B are compatible types like cm and km
                let (ttB, expB) = tcB.remove(at: y)
                
                if let defA = TypeDef.typeDict[ttA],
                   let defB = TypeDef.typeDict[ttB]
                {
                    // Compute the ratio of the compatible types cm/km, add to result is nonzero exp
                    let exp = expA + sign*expB
                    if exp != 0 {
                        tcQ.append( (ttA, exp) )
                    }
                    ratio *= sign == 1 ? defA.ratio/defB.ratio : defB.ratio/defA.ratio
                }
            }
            else {
                // Unit ttA does not appear in B, keep it in the result
                tcQ.append( (ttA, expA) )
            }
        }
        
        // Append remaining elements of B that did not appear in A
        for (tagB, expB) in tcB {
            tcQ.append( (tagB, sign*expB) )
        }
        
        normalizeTypeCode(&tcQ)
        return (tcQ, ratio)
        
    }
    return  nil
}


func lookupTypeTag( _ tc: TypeCode ) -> TypeTag? {
    /// lookupTypeTag( TypeCode ) -> TypeTag
    /// Find a type tag for the provided type code sequence
    ///
    let tsig = getTypeSig(tc)
    
    if let tag = TypeDef.sigDict[tsig] {
        // Matching tag is already defined
        return tag
    }
    else {
        // Find the unit signature from type code, 
        // [(km,1),(sec,-1)] -> [(length,1),(time,-1)] -> "length/time"
        //
        let uc = toUnitCode( from: tc )
        let usig = getUnitSig(uc)
        
        if let unit = UnitDef.sigDict[usig] {
            // Unit def already exists, add type def
            TypeDef.defineSigType(unit.uid, tsig)
        }
        else {
            let unit = UnitDef.defineUserUnit(usig)
            TypeDef.defineSigType(unit.uid, tsig)
        }
        
        return TypeDef.sigDict[tsig]
    }
}


// Common tag values
let tagNone: TypeTag = TypeTag(.none)
let tagUntyped: TypeTag = TypeTag(.untyped)

let tagRad = TypeTag(.angle, 2000)
