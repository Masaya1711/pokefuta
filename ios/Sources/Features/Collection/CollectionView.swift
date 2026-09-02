import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var manholeRepository: ManholeRepository
    @EnvironmentObject private var historyService: CheckinHistoryService
    @EnvironmentObject private var photoHistoryService: PhotoHistoryService

    private var checkedInManholes: [Manhole] {
        manholeRepository.manholes.filter { historyService.checkedInManholeIds.contains($0.id) }
    }

    private var photographedManholes: [Manhole] {
        manholeRepository.manholes.filter { photoHistoryService.photoManholeIds.contains($0.id) }
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
                        ManholeListView(
                            title: "収集済み",
                            manholes: checkedInManholes,
                            dateById: checkedInAtById
                        )
                    } label: {
                        countRow(title: "収集済み", count: checkedInManholes.count)
                    }

                    NavigationLink {
                        ManholeListView(
                            title: "写真撮影済",
                            manholes: photographedManholes,
                            dateById: photoHistoryService.photoDatesById
                        )
                    } label: {
                        countRow(title: "写真撮影済", count: photographedManholes.count)
                    }
                }

                if historyService.errorMessage != nil || photoHistoryService.errorMessage != nil {
                    Section("同期エラー") {
                        if let errorMessage = historyService.errorMessage {
                            Text("チェックイン: " + errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if let errorMessage = photoHistoryService.errorMessage {
                            Text("写真: " + errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("コレクション")
            .refreshable { await refresh() }
        }
        .task { await refresh() }
    }

    private func countRow(title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count) / \(manholeRepository.manholes.count)")
                .font(.title3.bold())
        }
    }

    private func refresh() async {
        guard let ownerRecordName = authService.userRecordName else { return }
        await historyService.refresh(ownerRecordName: ownerRecordName)
        await photoHistoryService.refresh(ownerRecordName: ownerRecordName)
    }
}
