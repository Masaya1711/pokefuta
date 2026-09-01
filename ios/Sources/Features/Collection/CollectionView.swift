import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var manholeRepository: ManholeRepository
    @EnvironmentObject private var historyService: CheckinHistoryService

    private var checkedInManholes: [Manhole] {
        manholeRepository.manholes.filter { historyService.checkedInManholeIds.contains($0.id) }
    }

    /// 同じポケふたに複数回チェックインしている場合は最新の日時を採用する。
    private var checkedInAtById: [String: Date] {
        var result: [String: Date] = [:]
        for checkin in historyService.checkins {
            guard let date = checkin.checkedInAt else { continue }
            if let existing = result[checkin.manholeId], existing >= date { continue }
            result[checkin.manholeId] = date
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CheckedInListView(
                            manholes: checkedInManholes,
                            checkedInAtById: checkedInAtById
                        )
                    } label: {
                        HStack {
                            Text("収集済み")
                            Spacer()
                            Text("\(checkedInManholes.count) / \(manholeRepository.manholes.count)")
                                .font(.title3.bold())
                        }
                    }
                }

                if let errorMessage = historyService.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("コレクション")
            .refreshable { await refresh() }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        guard let ownerRecordName = authService.userRecordName else { return }
        await historyService.refresh(ownerRecordName: ownerRecordName)
    }
}
