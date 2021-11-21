//
//  DisplayView.swift
//  MoneyCalc
//
//  Created by Barry Hall on 2021-10-28.
//
import Combine
import SwiftUI

class ObservableArray<T>: ObservableObject {

    @Published var array:[T] = []
    var cancellables = [AnyCancellable]()

    init(array: [T]) {
        self.array = array

    }

    func observeChildrenChanges<K>(_ type:K.Type) throws ->ObservableArray<T> where K : ObservableObject{
        let array2 = array as! [K]
        array2.forEach({
            let c = $0.objectWillChange.sink(receiveValue: { _ in self.objectWillChange.send() })

            // Important: You have to keep the returned value allocated,
            // otherwise the sink subscription gets cancelled
            self.cancellables.append(c)
        })
        return self
    }

}

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

struct NoPrefix: RowDataItem {
    let prefix = ""
    let register: String
    let suffix: String
    
    init(_ row: RowDataItem ) {
        self.register = row.register
        self.suffix = row.suffix
    }
}

struct TypedRegister: View {
    let row: RowDataItem
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
    @StateObject var model: CalculatorModel

    let rowHeight:Double = 25.0
    
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color("List0"))
                .frame(height: rowHeight*Double(model.rowCount) + 15.0)
            VStack( alignment: .leading, spacing: 5) {
                ForEach (0..<model.rowCount, id: \.self) { index in
                    TypedRegister( row: model.getRow(index: index), size: .normal ).padding(.leading, 10)
                }
            }
            .frame( height: rowHeight*Double(model.rowCount) )
        }
        .padding(15)
        .border(Color("Frame"), width: 10)
    }
}

// ************************************************************* //

struct MemoryDetailView: View {
    @StateObject var model: CalculatorModel

    @State private var editMode = EditMode.inactive
    @State private var editText = ""
        
    var index: Int
    var item: RowDataItem

    var body: some View {
        Form {
            TextField( "Memory Name", text: $editText,
                onEditingChanged: { _ in model.renameMemoryItem(index: index, newName: editText) }
//                onCommit: { model.renameMemoryItem(index: index, newName: editText) }
            )
            .onAppear {
                editText = item.prefix
            }

            TypedRegister( row: NoPrefix(item), size: .normal ).padding( .leading, 0)
        }
        
    }
}

struct MemoryDisplay: View {
    @StateObject var model: CalculatorModel
    
    @State private var editMode = EditMode.inactive

    let colWidth = 9.0
    let monoFont = Font.footnote

    @ViewBuilder
    private var addButton: some View {
        if editMode == .inactive {
            Button( action: { model.addMemoryItem() }) {
                Image( systemName: "plus") }
        } else {
            EmptyView()
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach ( Array( model.memoryRows.enumerated()), id: \.offset ) { index, item in
                    VStack( alignment: .leading ) {
                        NavigationLink {
                            MemoryDetailView(  model: model , index: index, item: item )
                        } label: {
                            Text( item.prefix ).font(monoFont).bold().listRowBackground(Color("List0"))
                        }
                        TypedRegister( row: NoPrefix(item), size: .small )
                    }
                }
                .onDelete( perform: { offsets in model.delMemoryItems( set: offsets) } )
            }
            .navigationBarTitle( "", displayMode: .inline )
            .navigationBarHidden(false)
            .navigationBarItems( leading: EditButton(), trailing: addButton)
            .environment( \.editMode, $editMode)
            .listStyle( PlainListStyle() )
            .padding( .horizontal, 0)
            .padding( .top, 0)
            .background( Color("Background") )
            .onAppear {
                UITableView.appearance().backgroundColor = UIColor(Color("Background"))
                UINavigationBar.appearance().backgroundColor = UIColor(Color("Background"))
            }
        }
        .navigationViewStyle( StackNavigationViewStyle())
        .padding(.top, 10)
    }
}

