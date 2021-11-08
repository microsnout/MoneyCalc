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

    init(_ content: String, charWidth: CGFloat) {
        self.content = content
        self.charWidth = charWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<self.content.count, id: \.self) { index in
                Text("\(self.content[self.content.index(self.content.startIndex, offsetBy: index)].description)")
                    .foregroundColor(Color.gray).frame(width: self.charWidth)
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
                .fill(Color("Display"))
                .frame(height: rowHeight*Double(rows) + 20.0)
            VStack( alignment: .leading, spacing: 5) {
                ForEach (0..<rows, id: \.self) { index in
                    HStack() {
                        Text( buffer[index].prefix).font(.system(size: 14.0)).bold().foregroundColor(Color("Frame"))
                        MonoText(
                            String( buffer[index].register ),
                            charWidth: colWidth)
                        Text( buffer[index].suffix).font(.system(size: 12.0)).bold().foregroundColor(Color.black)
                    }.padding(.leading, 10)
                }
            }
            .frame( height: rowHeight*Double(rows) )
        }
        .padding(15)
        .border(Color("Frame"), width: 10)
    }
}


