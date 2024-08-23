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
    let alignment: VerticalAlignment

    init(_ content: String, charWidth: CGFloat, font: Font = .body, align: VerticalAlignment = .center ) {
        self.content = content
        self.charWidth = charWidth
        self.font = font
        self.alignment = align
    }

    var body: some View {
        HStack( alignment: self.alignment, spacing: 0 ) {
            ForEach(0..<self.content.count, id: \.self) { index in
                Text("\(self.content[self.content.index(self.content.startIndex, offsetBy: index)].description)")
                    .font(font)
                    .foregroundColor(Color("DisplayText")).frame(width: self.charWidth)
            }
        }
    }
}

typealias TextSpec = ( prefixFont: Font, registerFont: Font, suffixFont: Font, monoSpace: Double )

enum TextSize {
    case normal, small, large
}

let textSpecTable: [TextSize: TextSpec] = [
    .normal : ( .footnote, .body, .footnote, 12.0 ),
    .small  : ( .caption, .footnote, .caption, 9.0 ),
    .large  : ( .footnote, .headline, .footnote, 12.0 )
]

protocol RowDataItem {
    var prefix:   String? { get }
    var register: String  { get }
    var exponent: String? { get }
    var suffix:   String? { get }
}

struct NoPrefix: RowDataItem {
    let prefix: String? = nil
    let register: String
    let exponent: String?
    let suffix: String?
    
    init(_ row: RowDataItem ) {
        self.register = row.register
        self.exponent = row.exponent
        self.suffix = row.suffix
    }
}

struct TypedRegister: View {
    let row: RowDataItem
    let size: TextSize
    
    var body: some View {
        if let spec = textSpecTable[size] {
            HStack( alignment: .bottom, spacing: 0 ) {
                if let prefix = row.prefix {
                    Text(prefix).font(spec.prefixFont).bold().foregroundColor(Color("Frame")).padding(.trailing, 10)
                }
                
                MonoText(row.register, charWidth: spec.monoSpace, font: spec.registerFont)
                
                if let exp: String = row.exponent {
                    MonoText(exp, charWidth: spec.monoSpace, font: spec.suffixFont, align: .bottom).alignmentGuide(.bottom, computeValue: { d in 25 })
                }
                
                if let suffix = row.suffix {
                    Text(suffix).font(spec.suffixFont).bold().foregroundColor(Color.gray).padding(.leading, 10)
                }
            }
            .frame( height: 20 )
        }
        else {
            EmptyView()
        }
    }
}

struct Display: View {
    @StateObject var model: CalculatorModel

    let rowHeight:Double = 35.0
    
    var body: some View {
        let _ = Self._printChanges()
        
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color("Display"))
            VStack( alignment: .leading, spacing: 5) {
                ForEach (0..<model.rowCount, id: \.self) { index in
                    TypedRegister( row: model.getRow(index: index), size: .large ).padding(.leading, 10)
                }
            }
            .frame( height: rowHeight*Double(model.rowCount) )
        }
        .padding(10)
        .border(Color("Frame"), width: 10)
    }
}

// ************************************************************* //

struct MemoryDetailView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @StateObject var model: CalculatorModel
    @State private var editMode = EditMode.inactive
    @State private var editText = ""
        
    var index: Int
    var item: RowDataItem

    var body: some View {
        Form {
            TextField( "-Unnamed-", text: $editText,
                onEditingChanged: { _ in model.renameMemoryItem(index: index, newName: editText) },
                onCommit: { self.presentationMode.wrappedValue.dismiss() }
            )
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .onAppear {
                if let name = item.prefix {
                    editText = name
                }
            }

            TypedRegister( row: NoPrefix(item), size: .normal ).padding( .leading, 0)
        }
        
    }
}

struct MemoryDisplay: View {
    @StateObject var model: CalculatorModel
    
    let leadingOps: [(key: KeyCode, text: String, color: Color)]
    
    @State private var editMode = EditMode.inactive

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
            let rows = model.state.memoryList
            
            if rows.isEmpty {
                Text("Memory List\n(Press + to store X register)")
                    .navigationBarTitle( "", displayMode: .inline )
                    .navigationBarHidden(false)
                    .navigationBarItems( trailing: addButton)
                    .foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/)
            }
            else {
                List {
                    ForEach ( Array( rows.enumerated()), id: \.offset ) { index, item in
                        VStack( alignment: .leading ) {
                            NavigationLink {
                                MemoryDetailView(  model: model , index: index, item: item )
                            } label: {
                                if let prefix = item.prefix {
                                    Text(prefix).font(.footnote).bold().listRowBackground(Color("List0"))
                                }
                                else {
                                    Text( "-Unnamed-" ).font(.footnote).foregroundColor(.gray).listRowBackground(Color("List0"))
                                }
                            }
                            TypedRegister( row: NoPrefix(item), size: .small )
                        }
                        .swipeActions( edge: .leading, allowsFullSwipe: true ) {
                            ForEach ( leadingOps, id: \.key) { key, text, color in
                                Button {
                                    model.memoryOp( key: key, index: index )
                                } label: { Text(text).bold() }.tint(color)
                            }
                        }
                        .swipeActions( edge: .trailing, allowsFullSwipe: false) {
                            Button( role: .destructive) {
                                model.delMemoryItems( set: IndexSet( [index] ))
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listRowSeparatorTint( Color("DisplayText"))
                    
                }
                .navigationBarTitle( "", displayMode: .inline )
                .navigationBarHidden(false)
                .navigationBarItems( trailing: addButton)
                .environment( \.editMode, $editMode)
                .listStyle( InsetListStyle() )
                .padding( .horizontal, 0)
                .padding( .top, 0)
            }
        }
        .navigationViewStyle( StackNavigationViewStyle())
        .padding(.top, 10)
    }
}

