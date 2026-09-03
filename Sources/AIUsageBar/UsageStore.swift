import Foundation
import Combine
import AIUsageBarCore

/// Owns the current lane table, the refresh timer and the error state.
/// Keeps the last good snapshot when a refresh fails (marked stale).
@MainActor
final class UsageStore: ObservableObject {
    static let refreshInterval: TimeInterval = 60
    static let staleThreshold: TimeInterval = 30

    @Published private(set) var table: LaneTable?
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading = false
    @Published private(set) var updatedAt: Date?
    @Published private(set) var isStale = false

    private let runner: any BackendRunner
    private var timer: Timer?
    private var inFlight: Task<Void, Never>?

    init(runner: any BackendRunner = ProcessBackendRunner()) {
        self.runner = runner
    }

    var iconState: StatusIcon.State {
        if lastError != nil { return .error }
        guard let table else { return .loading }
        return .ready(table.severity, fraction: peakFraction(table))
    }

    private func peakFraction(_ table: LaneTable) -> Double {
        let percents = table.vendors
            .flatMap(\.rows)
            .flatMap { [$0.session?.percent, $0.weekly?.percent] }
            .compactMap { $0 }
        return (percents.max() ?? 0) / 100
    }

    func start() {
        refresh()
        let timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        inFlight?.cancel()
    }

    /// Called when the popover opens; avoids hammering the cached backend.
    func refreshIfStale() {
        guard let updatedAt else { refresh(); return }
        if Date().timeIntervalSince(updatedAt) > Self.staleThreshold { refresh() }
    }

    func refresh() {
        guard inFlight == nil else { return }
        isLoading = true
        let runner = self.runner
        inFlight = Task { [weak self] in
            let result: Result<UsageSnapshot, any Error>
            do {
                result = .success(try await runner.fetch())
            } catch {
                result = .failure(error)
            }
            await MainActor.run {
                guard let self else { return }
                self.inFlight = nil
                self.isLoading = false
                switch result {
                case let .success(snapshot):
                    self.table = LaneBuilder.build(snapshot)
                    self.updatedAt = Date()
                    self.lastError = nil
                    self.isStale = snapshot.entries.contains(where: \.stale)
                case let .failure(error):
                    // Keep the previous snapshot visible, just flag it.
                    self.lastError = (error as? BackendError)?.errorDescription ?? error.localizedDescription
                    self.isStale = self.table != nil
                }
            }
        }
    }
}
