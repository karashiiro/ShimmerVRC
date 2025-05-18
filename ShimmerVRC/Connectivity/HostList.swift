//
//  HostList.swift
//  ShimmerVRC
//
//  Created by karashiiro on 5/18/25.
//

import SwiftUI

struct HostList: View {
    var hosts: [HostDiscovery.Host]
    @Binding var selectedHost: String

    var body: some View {
        ForEach(hosts, id: \.self) { h in
            HStack {
                Text(h.name)
                    .accessibility(identifier: "device_\(h.name.replacingOccurrences(of: ".", with: "_"))")
                    .onTapGesture { selectedHost = h.hostname }
                Spacer()
                if selectedHost == h.name {
                    Image(systemName: "checkmark")
                        .accessibility(identifier: "checkmark_\(h.name.replacingOccurrences(of: ".", with: "_"))")
                }
            }
            .accessibility(identifier: "device_row_\(h.name.replacingOccurrences(of: ".", with: "_"))")
        }
    }
}
