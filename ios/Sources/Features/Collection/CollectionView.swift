import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var manholeRepository: ManholeRepository
    @StateObject private var historyService = CheckinHistoryService()

    private var checkedInManholes: [Manhole] {
        manholeRepository.manholes.filter { historyService.checkedInManholeIds.contains($0.id) }
    }

    private var groupedByPrefecture: [(pref: String, manholes: [Manhole])] {
        Dictionary(grouping: checkedInManholes, by: \.prefName)
            .map { (pref: $0.key, manholes: $0.value) }
            .sorted { $0.pref < $1.pref }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("収集済み")
                        Spacer()
                        Text("\(checkedInManholes.count) / \(manholeRepository.manholes.count)")
                            .font(.title3.bold())
                    }
                }

                ForEach(groupedByPrefecture, id: \.pref) { group in
                    Section(group.pref) {
                        ForEach(group.manholes) { manhole in
                            NavigationLink(value: manhole) {
                                Text(manhole.displayTitle)
                            }
                        }
                    }
                }
            }
            .navigationTitle("コレクション")
            .navigationDestination(for: Manhole.self) { manhole in
                ManholeDetailView(manhole: manhole)
            }
        }
        .task {
            if let ownerRecordName = authService.userRecordName {
                await historyService.refresh(ownerRecordName: ownerRecordName)
            }
        }
    }
}
