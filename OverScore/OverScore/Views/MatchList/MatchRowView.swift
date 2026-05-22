import SwiftUI

struct MatchRowView: View {
    let match: Match
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
                .frame(width: 80, height: 45)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(match.homeTeamName)
                        .font(.subheadline.weight(.semibold))
                    Text("\(match.homeScore) - \(match.awayScore)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                    Text(match.awayTeamName)
                        .font(.subheadline.weight(.semibold))
                }

                HStack(spacing: 4) {
                    Text(match.createdAt, style: .date)
                    if let info = match.matchInfo, !info.isEmpty {
                        Text("·")
                        Text(info)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadThumbnail()
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "sportscourt")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func loadThumbnail() async {
        guard let url = match.videoURLs.first else { return }
        thumbnail = await ThumbnailGenerator.generate(for: url)
    }
}
