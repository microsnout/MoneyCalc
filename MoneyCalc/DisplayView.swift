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

typealias TextSpec = ( prefixFont: Font, registerFont: Font, suffixFont: Font, monoSpace: Double )

enum TextSize {
    case normal, small
}

let textSpecTable: [TextSize: TextSpec] = [
    .normal : ( .footnote, .body, .footnote, 12.0 ),
    .small  : ( .caption, .footnote, .caption, 9.0 )
]

protocol RowDataItem {
    var prefix:   String { get }
    var register: String { get }
    var suffix:   String { get }
}

struct RowData {
    var prefix:   String = ""
    var register: String
    var suffix:   String = ""
    
    func noPrefix() -> RowData {
        return RowData( register: register, suffix: suffix )
    }
}

struct TypedRegister: View {
    let row: RowData
    let size: TextSize
    
    var body: some View {
        if let spec = textSpecTable[size] {
            HStack {
                if !row.prefix.isEmpty {
                    Text(row.prefix).font(spec.prefixFont).bold().foregroundColor(Color("Frame"))
                }
                MonoText(row.register, charWidth: spec.monoSpace, font: spec.registerFont)
                Text(row.suffix).font(spec.suffixFont).bold().foregroundColor(Color.gray)
            }
        }
        else {
            EmptyView()
        }
    }
}

struct Display: View {
    let rows: Int
    let rowHeight:Double = 25.0
    let buffer: [RowData]
    
    init( buffer: [RowData] ) {
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
                    TypedRegister( row: buffer[index], size: .normal ).padding(.leading, 10)
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
    func renameMemoryItem( index: Int, newName: String )
}

struct MemoryItem: Identifiable {
    private static var index = 0
    
    let id: Int
    var row: RowData
    
    init( prefix: String, register: String, suffix: String = "" ) {
        row = RowData( prefix: prefix, register: register, suffix: suffix )
        id = MemoryItem.index
        MemoryItem.index += 1
    }
}

struct MemoryDetailView: View {
    @State private var editMode = EditMode.inactive
    @State private var editText = ""
    
    var displayHandler: MemoryDisplayHandler
    
    var item: MemoryItem
    
    init( item: MemoryItem, displayHandler: MemoryDisplayHandler ) {
        self.item = item
        self.displayHandler = displayHandler
    }
    
    var body: some View {
        Form {
            TextField( "Memory Name", text: $editText,
                onCommit: { displayHandler.renameMemoryItem(index: 0, newName: editText) }
            )
            .onAppear {
                editText = item.row.prefix
            }

            TypedRegister( row: item.row.noPrefix(), size: .normal ).padding( .leading, 0)
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
                            MemoryDetailView( item: item, displayHandler: displayHandler )
                        } label: {
                            Text( item.row.prefix ).font(monoFont).bold().listRowBackground(Color("List0"))
                        }
                        TypedRegister( row: item.row.noPrefix(), size: .small )
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

