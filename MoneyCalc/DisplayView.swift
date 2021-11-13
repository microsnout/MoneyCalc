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
                        Text( buffer[index].prefix).font(.system(size: 14.0)).bold().foregroundColor(Color("Frame"))
                        MonoText(
                            String( buffer[index].register ),
                            charWidth: colWidth)
                        Text( buffer[index].suffix).font(.system(size: 12.0)).bold().foregroundColor(Color.gray)
                    }.padding(.leading, 10)
                }
            }
            .frame( height: rowHeight*Double(rows) )
        }
        .padding(15)
        .border(Color("Frame"), width: 10)
    }
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

struct MemoryDisplay: View {
    @State private var list: [MemoryItem]
    @State private var editMode = EditMode.inactive
    
    let colWidth = 10.0
    let monoFont = Font.footnote

    init( list: [MemoryItem] ) {
        _list = State( initialValue: list)
        
//        UITableView.appearance().rowHeight = CGFloat(36.0)
        UITableView.appearance().backgroundColor = UIColor(Color("Background"))
        UINavigationBar.appearance().backgroundColor = UIColor(Color("Background"))
    }
    
    private var addButton: some View {
        return editMode == .inactive ?
            AnyView( Button(action: onAdd) { Image( systemName: "plus") }) :
            AnyView( EmptyView())
    }
        
    var body: some View {
        NavigationView {
            List {
                ForEach ( list ) { item in
                    let back = item.id % 2 == 0 ? Color("List0") : Color("List1")
                                 
                    VStack( alignment: .leading ) {
                        Text( item.row.prefix ).font(monoFont).bold().listRowBackground(back)
                        HStack {
                            MonoText( item.row.register, charWidth: colWidth, font: .footnote)
                                .listRowBackground(back)
                            Text( item.row.suffix ).font(.caption).listRowBackground(back)
                        }
                        .padding( .leading, 30)
                    }
                }
                .onDelete { indexSet in
                    list.remove( atOffsets: indexSet)
                }
                .onMove { indexSet, index in
                    list.move( fromOffsets: indexSet, toOffset: index)
                }
                
            }
            .navigationBarTitle( "", displayMode: .inline )
            .navigationBarHidden(false)
            .navigationBarItems( leading: EditButton(), trailing: addButton)
            .environment( \.editMode, $editMode)
            .listStyle( PlainListStyle() )
            .padding( .horizontal, 0)
            .padding( .top, 0)
            .background(Color("Background"))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .padding(.top, 10)
    }

    func onAdd() {
        // To be implemented in the next section
    }
}


