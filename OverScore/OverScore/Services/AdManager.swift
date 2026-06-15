import GoogleMobileAds
import UIKit

@MainActor
@Observable
final class AdManager: NSObject {
    static let shared = AdManager()

    #if DEBUG
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // TODO: 本番用IDに差し替え
    #endif

    private var interstitialAd: InterstitialAd?
    private var adDismissedContinuation: CheckedContinuation<Void, Never>?

    var isAdReady: Bool { interstitialAd != nil }

    func configure() {
        MobileAds.shared.start { _ in }
    }

    func loadInterstitialAd() {
        let request = Request()
        let adUnitID = interstitialAdUnitID
        Task { @MainActor [weak self] in
            do {
                let ad = try await InterstitialAd.load(with: adUnitID, request: request)
                self?.interstitialAd = ad
                ad.fullScreenContentDelegate = self
            } catch {
                // Ad load failed, silently continue
            }
        }
    }

    func showInterstitialAd() async {
        guard let ad = interstitialAd,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        await withCheckedContinuation { continuation in
            adDismissedContinuation = continuation
            ad.present(from: topVC)
        }
    }
}

extension AdManager: @preconcurrency FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitialAd = nil
        adDismissedContinuation?.resume()
        adDismissedContinuation = nil
        loadInterstitialAd()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        interstitialAd = nil
        adDismissedContinuation?.resume()
        adDismissedContinuation = nil
        loadInterstitialAd()
    }
}
