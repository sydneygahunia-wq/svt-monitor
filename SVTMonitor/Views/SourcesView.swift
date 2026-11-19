import SwiftUI

/// Settings › Sources: every piece of health guidance in the app, with what it
/// backs and a link to the original.
struct SourcesView: View {
    var body: some View {
        List {
            Section {
                ForEach(HealthSource.all) { source in
                    Link(destination: source.url) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.title)
                                .font(Theme.font(16, .semibold))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            Text(source.publisher)
                                .font(Theme.font(14))
                                .foregroundStyle(Theme.accent)
                            Text("Used for: \(source.usedFor)")
                                .font(Theme.font(14))
                                .foregroundStyle(Theme.inkSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityHint("Opens in Safari")
                }
            } footer: {
                Text("SVT Monitor is a personal tracking tool, not a medical device. These sources explain where its wording comes from; they aren't a substitute for advice from your own care team.")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SourcesView() }
}
