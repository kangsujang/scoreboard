import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct VideoEntry: Identifiable {
    let id = UUID()
    let url: URL
    var thumbnail: UIImage?
}

struct MatchSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @State private var homeTeamName = ""
    @State private var awayTeamName = ""
    @State private var matchInfo = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var videoEntries: [VideoEntry] = []
    @State private var isImporting = false
    @State private var errorMessage: String?

    private var canProceed: Bool {
        !homeTeamName.trimmingCharacters(in: .whitespaces).isEmpty
        && !awayTeamName.trimmingCharacters(in: .whitespaces).isEmpty
        && !videoEntries.isEmpty
    }

    var body: some View {
        Form {
            Section("チーム名") {
                TextField("ホームチーム", text: $homeTeamName)
                    .textInputAutocapitalization(.words)
                TextField("アウェイチーム", text: $awayTeamName)
                    .textInputAutocapitalization(.words)
            }

            Section {
                TextField("例: 第100回全国高校サッカー選手権 決勝", text: $matchInfo)
            } header: {
                Text("試合情報")
            } footer: {
                Text("大会名や日程など、スコアボードに表示する情報")
            }

            Section {
                if !videoEntries.isEmpty {
                    ForEach(videoEntries) { entry in
                        HStack(spacing: 12) {
                            if let thumb = entry.thumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 45)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Rectangle()
                                    .fill(.quaternary)
                                    .frame(width: 80, height: 45)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay {
                                        Image(systemName: "video")
                                            .foregroundStyle(.secondary)
                                    }
                            }

                            Text(entry.url.lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .onMove { from, to in
                        videoEntries.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { offsets in
                        videoEntries.remove(atOffsets: offsets)
                    }
                }

                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .videos
                ) {
                    Label(
                        isImporting ? "読み込み中..." : "動画を追加",
                        systemImage: "video.badge.plus"
                    )
                }
                .disabled(isImporting)
            } header: {
                Text("試合動画")
            } footer: {
                if videoEntries.count > 1 {
                    Text("ドラッグで並び替え、スワイプで削除できます。動画は上から順に結合されます。")
                }
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
        .environment(\.editMode, .constant(.active))
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await importVideos(from: newItems)
                selectedItems = []
            }
        }
    }

    private func importVideos(from items: [PhotosPickerItem]) async {
        isImporting = true
        errorMessage = nil

        for item in items {
            do {
                guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
                    continue
                }

                let sandboxURL = try await VideoImportService.copyToSandbox(from: movie.url)
                let thumb = await ThumbnailGenerator.generate(for: sandboxURL)
                await MainActor.run {
                    videoEntries.append(VideoEntry(url: sandboxURL, thumbnail: thumb))
                }
            } catch {
                await MainActor.run {
                    errorMessage = "動画のインポートに失敗: \(error.localizedDescription)"
                }
            }
        }

        await MainActor.run {
            isImporting = false
        }
    }

    private func createMatch() {
        let match = Match(
            homeTeamName: homeTeamName.trimmingCharacters(in: .whitespaces),
            awayTeamName: awayTeamName.trimmingCharacters(in: .whitespaces)
        )
        let trimmedInfo = matchInfo.trimmingCharacters(in: .whitespaces)
        if !trimmedInfo.isEmpty {
            match.matchInfo = trimmedInfo
        }
        match.videoURLs = videoEntries.map(\.url)
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
