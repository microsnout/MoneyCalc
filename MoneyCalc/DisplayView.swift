//
//  DisplayView.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//

import SwiftUI

struct MonoText: View {
    let content: String
    let charWidth: CGFloat
    let font: Font

    init(_ content: String, charWidth: CGFloat, font: Font = .body ) {
        self.content = content
        self.charWidth = charWidth
        self.font = font
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<self.content.count, id: \.self) { index in
                Text("\(self.content[self.content.index(self.content.startIndex, offsetBy: index)].description)")
                    .font(font)
                    .foregroundColor(Color.black).frame(width: self.charWidth)
            }
        }
    }
}

struct DisplayRow {
    var prefix: String = ""
    var register: String = ""
    var suffix: String = ""
}

struct TypedRegister: View {
    let reg: String, regFont: Font, colWidth: Double
    let type: String, typeFont: Font
    
    var body: some View {
        HStack {
            MonoText(reg, charWidth: colWidth, font: regFont)
            Text(type).font(typeFont).bold().foregroundColor(Color.gray)
        }
    }
}

struct Display: View {
    let rows: Int
    let rowHeight:Double = 25.0
    let colWidth:Double = 12.0
    let buffer: [DisplayRow]
    
    init( buffer: [DisplayRow] ) {
        self.buffer = buffer
        self.rows = buffer.count
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color("List0"))
                .frame(height: rowHeight*Double(rows) + 15.0)
            VStack( alignment: .leading, spacing: 5) {
                ForEach (0..<rows, id: \.self) { index in
                    HStack() {
                        Text( buffer[index].prefix).font(.body).bold().foregroundColor(Color("Frame"))
                        TypedRegister( reg: buffer[index].register, regFont: .body, colWidth: colWidth,
                                       type: buffer[index].suffix, typeFont: .footnote )
                    }.padding(.leading, 10)
                }
            }
            .frame( height: rowHeight*Double(rows) )
        }
        .padding(15)
        .border(Color("Frame"), width: 10)
    }
}

// ************************************************************* //

protocol MemoryDisplayHandler {
    func addMemoryItem()
    func delMemoryItems( set: IndexSet )
}

struct MemoryItem: Identifiable {
    private static var index = 0
    
    let id: Int
    var row: DisplayRow
    
    init() {
        row = DisplayRow()
        id = MemoryItem.index
        MemoryItem.index += 1
    }
    
    init( prefix: String, register: String, suffix: String = "" ) {
        row = DisplayRow( prefix: prefix, register: register, suffix: suffix )
        id = MemoryItem.index
        MemoryItem.index += 1
    }
}

struct MemoryDetail: View {
    @State private var editMode = EditMode.inactive
    
    let item: MemoryItem
    
    init( item: MemoryItem ) {
        self.item = item
    }
    
    var body: some View {
        VStack {
//            TextField( text: $caption )
            HStack {
                TypedRegister( reg: item.row.register, regFont: .footnote, colWidth: 9.0,
                               type: item.row.suffix, typeFont: .caption )
            }
            .padding( .leading, 0)
        }
    }
}

struct MemoryDisplay: View {
    @State private var editMode = EditMode.inactive
    
    var list: [MemoryItem]

    let colWidth = 9.0
    let monoFont = Font.footnote
    
    var displayHandler: MemoryDisplayHandler

    init( list: [MemoryItem], displayHandler: MemoryDisplayHandler ) {
        self.list = list
        self.displayHandler = displayHandler
        
//        UITableView.appearance().rowHeight = CGFloat(36.0)
        UITableView.appearance().backgroundColor = UIColor(Color("Background"))
        UINavigationBar.appearance().backgroundColor = UIColor(Color("Background"))
    }
    
    @ViewBuilder
    private var addButton: some View {
        if editMode == .inactive {
            Button( action: { displayHandler.addMemoryItem() }) {
                Image( systemName: "plus") }
        } else {
            EmptyView()
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach ( list ) { item in
                    VStack( alignment: .leading ) {
                        NavigationLink {
                            MemoryDetail( item: item )
                        } label: {
                            Text( item.row.prefix ).font(monoFont).bold().listRowBackground(Color("List0"))
                        }
                        TypedRegister( reg: item.row.register, regFont: .footnote, colWidth: colWidth,
                                           type: item.row.suffix, typeFont: .caption )
                    }
                }
                .onDelete( perform: { offsets in displayHandler.delMemoryItems( set: offsets) } )
            }
            .navigationBarTitle( "", displayMode: .inline )
            .navigationBarHidden(false)
            .navigationBarItems( leading: EditButton(), trailing: addButton)
            .environment( \.editMode, $editMode)
            .listStyle( PlainListStyle() )
            .padding( .horizontal, 0)
            .padding( .top, 0)
            .background( Color("Background") )
        }
        .navigationViewStyle( StackNavigationViewStyle())
        .padding(.top, 10)
    }
}

