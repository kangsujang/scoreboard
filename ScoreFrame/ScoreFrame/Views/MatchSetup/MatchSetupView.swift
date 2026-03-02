import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct MatchSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @State private var homeTeamName = ""
    @State private var awayTeamName = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var thumbnail: UIImage?
    @State private var isImporting = false
    @State private var errorMessage: String?

    private var canProceed: Bool {
        !homeTeamName.trimmingCharacters(in: .whitespaces).isEmpty
        && !awayTeamName.trimmingCharacters(in: .whitespaces).isEmpty
        && videoURL != nil
    }

    var body: some View {
        Form {
            Section("チーム名") {
                TextField("ホームチーム", text: $homeTeamName)
                    .textInputAutocapitalization(.words)
                TextField("アウェイチーム", text: $awayTeamName)
                    .textInputAutocapitalization(.words)
            }

            Section("試合動画") {
                PhotosPicker(selection: $selectedItem, matching: .videos) {
                    if let thumbnail {
                        HStack {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 68)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading) {
                                Text("動画を選択済み")
                                    .font(.subheadline)
                                Text("タップして変更")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Label(
                            isImporting ? "読み込み中..." : "動画を選択",
                            systemImage: "video.badge.plus"
                        )
                    }
                }
                .disabled(isImporting)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section {
                Button {
                    createMatch()
                } label: {
                    HStack {
                        Spacer()
                        Text("スコア記録開始")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(!canProceed)
            }
        }
        .navigationTitle("新規試合")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await importVideo(from: newItem)
            }
        }
    }

    private func importVideo(from item: PhotosPickerItem) async {
        isImporting = true
        errorMessage = nil

        do {
            guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
                errorMessage = "動画の読み込みに失敗しました"
                isImporting = false
                return
            }

            let sandboxURL = try await VideoImportService.copyToSandbox(from: movie.url)
            await MainActor.run {
                videoURL = sandboxURL
            }

            let thumb = await ThumbnailGenerator.generate(for: sandboxURL)
            await MainActor.run {
                thumbnail = thumb
                isImporting = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "動画のインポートに失敗: \(error.localizedDescription)"
                isImporting = false
            }
        }
    }

    private func createMatch() {
        let match = Match(
            homeTeamName: homeTeamName.trimmingCharacters(in: .whitespaces),
            awayTeamName: awayTeamName.trimmingCharacters(in: .whitespaces)
        )
        match.videoURL = videoURL
        modelContext.insert(match)
        router.navigate(to: .scoreEditor(match))
    }
}

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}
