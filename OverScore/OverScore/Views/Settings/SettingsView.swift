import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var storeManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if storeManager.isAdRemoved {
                        Label("広告は削除済みです", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if let product = storeManager.removeAdsProduct {
                        Button {
                            Task { await storeManager.purchase() }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("広告を削除")
                                        .font(.headline)
                                    Text("エクスポート時の広告を非表示にします")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .disabled(storeManager.isLoading)
                    } else {
                        if storeManager.isLoading {
                            ProgressView("読み込み中...")
                        } else {
                            Text("商品情報を取得できません")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("購入を復元") {
                        Task { await storeManager.restore() }
                    }
                    .disabled(storeManager.isLoading || storeManager.isAdRemoved)
                } header: {
                    Text("アプリ内課金")
                } footer: {
                    if let error = storeManager.purchaseError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section("アプリ情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
