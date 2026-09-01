import SwiftUI

/// チェックイン済みポケふたの一覧。公式画像付きで1件ずつ表示し、並び替えと検索ができる。
struct CheckedInListView: View {
    let manholes: [Manhole]
    /// ポケふたIDごとの最新チェックイン日時
    let checkedInAtById: [String: Date]

    @State private var sortKey: SortKey = .date
    @State private var ascending = false
    @State private var searchText = ""

    enum SortKey: String, CaseIterable, Identifiable {
        case date = "日付"
        case prefecture = "都道府県"

        var id: String { rawValue }
    }

    private var filteredManholes: [Manhole] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return manholes }
        return manholes.filter {
            $0.prefName.contains(keyword)
                || $0.city.contains(keyword)
                || $0.address.contains(keyword)
                || $0.pokemonList.contains { $0.name.contains(keyword) }
        }
    }

    private var sortedManholes: [Manhole] {
        let sorted = filteredManholes.sorted { lhs, rhs in
            switch sortKey {
            case .date:
                let lhsDate = checkedInAtById[lhs.id] ?? .distantPast
                let rhsDate = checkedInAtById[rhs.id] ?? .distantPast
                if lhsDate == rhsDate { return lhs.displayTitle < rhs.displayTitle }
                return lhsDate < rhsDate
            case .prefecture:
                if lhs.prefName == rhs.prefName { return lhs.displayTitle < rhs.displayTitle }
                return lhs.prefName < rhs.prefName
            }
        }
        return ascending ? sorted : sorted.reversed()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    var body: some View {
        List {
            if sortedManholes.isEmpty {
                Text(searchText.isEmpty
                     ? "まだチェックインしたポケふたがありません。"
                     : "該当するポケふたがありません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedManholes) { manhole in
                    NavigationLink {
                        ManholeDetailView(manhole: manhole)
                    } label: {
                        row(for: manhole)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("収集済み \(sortedManholes.count)件")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "都道府県・市区町村・住所・ポケモン名")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("並び替え", selection: $sortKey) {
                        ForEach(SortKey.allCases) { key in
                            Text(key.rawValue).tag(key)
                        }
                    }
                    Divider()
                    Picker("並び順", selection: $ascending) {
                        Text("昇順").tag(true)
                        Text("降順").tag(false)
                    }
                } label: {
                    Label("並び替え", systemImage: "arrow.up.arrow.down")
                }
            }
        }
    }

    /// 1段ぶんの表示。画像は撮影写真ではなく公式サイトの正規画像を使う。
    private func row(for manhole: Manhole) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: manhole.imageUrl)) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Color(.secondarySystemBackground)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(manhole.displayTitle)
                    .font(.subheadline.weight(.semibold))
                if let date = checkedInAtById[manhole.id] {
                    Text(Self.dateFormatter.string(from: date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !manhole.pokemonList.isEmpty {
                    Text(manhole.pokemonList.map(\.name).joined(separator: "、"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
