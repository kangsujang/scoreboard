import SwiftUI

/// ピンチイン/ピンチアウトで拡大・縮小し、拡大中はドラッグでパンできるコンテナ。
/// スコア記録画面の動画プレビュー（iPhoneでは画面が小さく細部が見づらい）で使用する。
struct ZoomableView<Content: View>: View {
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 6.0
    /// ダブルタップ1回で寄る倍率
    private let doubleTapScale: CGFloat = 2.5

    @ViewBuilder var content: () -> Content

    /// 表示中の倍率（ジェスチャ中も逐次更新）
    @State private var scale: CGFloat = 1
    /// ジェスチャ開始時点の倍率
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    /// ピンチ中はパンを無視する（両ジェスチャがoffsetを奪い合うのを防ぐ）
    @State private var isMagnifying = false
    /// パン開始時点の状態。ピンチ後にパンを再開しても飛ばないよう、都度取り直す。
    @State private var panBase: PanBase?

    private struct PanBase {
        let offset: CGSize
        let translation: CGSize
    }

    private var isZoomed: Bool { scale > minScale + 0.01 }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            content()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: size.width, height: size.height)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(magnifyGesture(in: size))
                // 等倍のときはパンを無効化し、画面端スワイプ（戻る）を妨げない
                .gesture(panGesture(in: size), including: isZoomed ? .all : .subviews)
                .onTapGesture(count: 2) {
                    toggleZoom()
                }
                .overlay(alignment: .bottomTrailing) {
                    if isZoomed {
                        resetButton
                            .padding(8)
                            .transition(.opacity)
                    }
                }
        }
    }

    private var resetButton: some View {
        Button {
            toggleZoom(forceReset: true)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                Text("\(scale, specifier: "%.1f")x")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.55), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("ズームをリセット")
    }

    // MARK: - Gestures

    private func magnifyGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = clampedScale(baseScale * value.magnification)
                // ピンチ開始位置を固定点として拡大する（中心固定より狙った場所に寄せやすい）
                let anchor = CGPoint(
                    x: (value.startAnchor.x - 0.5) * size.width,
                    y: (value.startAnchor.y - 0.5) * size.height
                )
                let ratio = newScale / baseScale
                let proposed = CGSize(
                    width: anchor.x - (anchor.x - baseOffset.width) * ratio,
                    height: anchor.y - (anchor.y - baseOffset.height) * ratio
                )
                isMagnifying = true
                panBase = nil
                scale = newScale
                offset = clampedOffset(proposed, scale: newScale, size: size)
            }
            .onEnded { _ in
                isMagnifying = false
                panBase = nil
                commitGestureState()
            }
    }

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard isZoomed, !isMagnifying else {
                    panBase = nil
                    return
                }
                let base = panBase ?? PanBase(offset: offset, translation: value.translation)
                if panBase == nil {
                    panBase = base
                }
                let proposed = CGSize(
                    width: base.offset.width + (value.translation.width - base.translation.width),
                    height: base.offset.height + (value.translation.height - base.translation.height)
                )
                offset = clampedOffset(proposed, scale: scale, size: size)
            }
            .onEnded { _ in
                panBase = nil
                commitGestureState()
            }
    }

    // MARK: - Helpers

    private func toggleZoom(forceReset: Bool = false) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isZoomed || forceReset {
                scale = minScale
                offset = .zero
            } else {
                scale = doubleTapScale
                offset = .zero
            }
            commitGestureState()
        }
    }

    private func commitGestureState() {
        baseScale = scale
        baseOffset = offset
        panBase = nil
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minScale), maxScale)
    }

    /// 拡大後のコンテンツが枠から離れないようにパン量を制限する
    private func clampedOffset(_ proposed: CGSize, scale: CGFloat, size: CGSize) -> CGSize {
        let maxX = max(0, (size.width * scale - size.width) / 2)
        let maxY = max(0, (size.height * scale - size.height) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
}
