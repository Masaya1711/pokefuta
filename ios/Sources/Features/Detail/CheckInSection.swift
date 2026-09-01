import SwiftUI
import PhotosUI

struct CheckInSection: View {
    let manhole: Manhole
    @ObservedObject var detailService: ManholeDetailService

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkinHistoryService: CheckinHistoryService

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var showCamera = false
    @State private var isSubmitting = false
    @State private var isUploadingPhoto = false
    @State private var errorMessage: String?
    @State private var photoStatusMessage: String?
    @State private var didCheckIn = false

    private var distance: Double? { locationManager.distance(to: manhole) }
    private var isWithinRange: Bool {
        guard let distance else { return false }
        return distance <= LocationManager.checkInThresholdMeters
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let distance {
                Text("現在地からの距離: " + Self.formattedDistance(distance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let pendingImageData, let uiImage = UIImage(data: pendingImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("写真を選択", systemImage: "photo")
                }
                Button {
                    showCamera = true
                } label: {
                    Label("カメラで撮影", systemImage: "camera")
                }
            }
            .font(.subheadline)

            // 写真投稿はチェックイン可否と切り離し、距離に関係なくいつでも行えるようにする。
            if pendingImageData != nil {
                Button {
                    uploadPhotoOnly()
                } label: {
                    if isUploadingPhoto {
                        ProgressView()
                    } else {
                        Label("この写真を投稿する", systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isUploadingPhoto || isSubmitting)
            }

            if let photoStatusMessage {
                Text(photoStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                checkIn()
            } label: {
                if isSubmitting {
                    ProgressView()
                } else if didCheckIn {
                    Label("チェックイン済み", systemImage: "checkmark.seal.fill")
                } else {
                    Text("ここでチェックインする")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isWithinRange || isSubmitting || isUploadingPhoto || didCheckIn)

            if !isWithinRange {
                Text("設置場所から\(LocationManager.checkInThresholdDisplayText)以内に近づくとチェックインできます。写真の投稿は距離に関係なくできます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .task(id: selectedPhotoItem) {
            guard let selectedPhotoItem else { return }
            pendingImageData = try? await selectedPhotoItem.loadTransferable(type: Data.self)
            photoStatusMessage = nil
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(imageData: $pendingImageData)
        }
    }

    private static func formattedDistance(_ meters: Double) -> String {
        meters >= 1000
            ? String(format: "約%.1fkm", meters / 1000)
            : String(format: "約%.0fm", meters)
    }

    /// チェックインせずに写真だけを投稿する。
    private func uploadPhotoOnly() {
        guard let ownerRecordName = authService.userRecordName, let imageData = pendingImageData else { return }
        isUploadingPhoto = true
        errorMessage = nil
        photoStatusMessage = nil

        Task {
            do {
                try await PhotoUploadService().uploadCheckinPhoto(
                    manholeId: manhole.id,
                    ownerRecordName: ownerRecordName,
                    imageData: imageData
                )
                await detailService.refresh()
                pendingImageData = nil
                selectedPhotoItem = nil
                photoStatusMessage = "写真を投稿しました。"
            } catch {
                errorMessage = error.localizedDescription
            }
            isUploadingPhoto = false
        }
    }

    private func checkIn() {
        guard let ownerRecordName = authService.userRecordName, let distance else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                if let imageData = pendingImageData {
                    try await PhotoUploadService().uploadCheckinPhoto(
                        manholeId: manhole.id,
                        ownerRecordName: ownerRecordName,
                        imageData: imageData
                    )
                    // 同じ写真がチェックイン時に二重投稿されないよう、送信済みの分は破棄する。
                    pendingImageData = nil
                    selectedPhotoItem = nil
                }
                try await detailService.addCheckin(
                    ownerRecordName: ownerRecordName,
                    method: .gpsAuto,
                    distanceMeters: distance
                )
                await detailService.refresh()
                await checkinHistoryService.refresh(ownerRecordName: ownerRecordName)
                didCheckIn = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
