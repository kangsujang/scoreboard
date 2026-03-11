import SwiftUI
import AVKit

struct ExportView: View {
    let match: Match
    @State private var viewModel: ExportViewModel?
    @State private var player: AVPlayer?
    @State private var videoAspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        Group {
            if let vm = viewModel {
                exportContent(vm: vm)
            } else {
                ProgressView("準備中...")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("エクスポート")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let vm = ExportViewModel(match: match)
            viewModel = vm
            vm.startExport()
            Task {
                if let url = match.videoURLs.first,
                   let size = await ThumbnailGenerator.videoSize(for: url) {
                    videoAspectRatio = size.width / size.height
                }
            }
        }
        .onDisappear {
            player?.pause()
            viewModel?.cleanupExportedFile()
        }
    }

    @ViewBuilder
    private func exportContent(vm: ExportViewModel) -> some View {
        VStack(spacing: 16) {
            if vm.isExporting {
                exportingView(vm: vm)
            } else if let url = vm.exportedURL {
                completedView(vm: vm, url: url)
            } else if let error = vm.exportError {
                errorView(error: error)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: Binding(
            get: { vm.showShareSheet },
            set: { vm.showShareSheet = $0 }
        )) {
            if let url = vm.exportedURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportingView(vm: ExportViewModel) -> some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView(value: vm.progress) {
                Text("エクスポート中...")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(Int(vm.progress * 100))%")
                    .monospacedDigit()
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: 300)

            Text("\(match.homeTeamName) \(match.homeScore) - \(match.awayScore) \(match.awayTeamName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("キャンセル", role: .destructive) {
                vm.cancelExport()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    private func completedView(vm: ExportViewModel, url: URL) -> some View {
        VStack(spacing: 16) {
            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(videoAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Label("エクスポート完了", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            HStack(spacing: 16) {
                Button {
                    vm.showShareSheet = true
                } label: {
                    Label("共有", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    vm.saveToPhotos()
                } label: {
                    Label(
                        vm.savedToPhotos ? "保存済み" : "写真に保存",
                        systemImage: vm.savedToPhotos ? "checkmark" : "photo.on.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(vm.savedToPhotos)
            }
            .frame(maxWidth: 400)

            if let saveError = vm.saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)
        }
        .onAppear {
            player = AVPlayer(url: url)
        }
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text("エクスポートに失敗しました")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("再試行") {
                viewModel?.startExport()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }
}
