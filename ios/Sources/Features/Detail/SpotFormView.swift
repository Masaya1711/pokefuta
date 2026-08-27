import SwiftUI

struct SpotFormView: View {
    @ObservedObject var detailService: ManholeDetailService
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: SpotCategory = .restaurant
    @State private var rating = 5
    @State private var comment = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("スポット情報") {
                    TextField("店名・スポット名", text: $name)
                    Picker("カテゴリ", selection: $category) {
                        ForEach(SpotCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }

                Section("評価") {
                    HStack {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                                .onTapGesture { rating = star }
                        }
                    }
                    TextField("コメント", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("おすすめスポットを投稿")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("投稿") { submit() }
                        .disabled(name.isEmpty || isSubmitting)
                }
            }
        }
    }

    private func submit() {
        guard let userId = authService.currentUser?.uid else { return }
        isSubmitting = true
        do {
            let location = locationManager.currentLocation
            try detailService.addSpot(
                userId: userId,
                name: name,
                category: category,
                rating: rating,
                comment: comment,
                lat: location?.coordinate.latitude,
                lng: location?.coordinate.longitude
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
