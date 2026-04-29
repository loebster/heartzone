//
//  ContentView.swift
//  Heartzone Watch App
//
//  Created by Christian Loeb on 29.04.26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "bicycle")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Heartzone!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
