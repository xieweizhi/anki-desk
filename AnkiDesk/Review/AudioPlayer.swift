import AVFoundation
import Observation

/// Plays a card side's sounds one after another.
@Observable
final class AudioPlayer {
    private(set) var isPlaying = false
    /// 0...1 across the whole queue.
    private(set) var progress: Double = 0

    private var player: AVPlayer?
    private var queue: [URL] = []
    private var index = 0
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    func play(_ urls: [URL]) {
        stop()
        guard !urls.isEmpty else { return }
        queue = urls
        index = 0
        isPlaying = true
        playCurrent()
    }

    func toggle(_ urls: [URL]) {
        if isPlaying { stop() } else { play(urls) }
    }

    func stop() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        player?.pause()
        player = nil
        isPlaying = false
        progress = 0
    }

    private func playCurrent() {
        guard index < queue.count else {
            stop()
            return
        }
        let item = AVPlayerItem(url: queue[index])
        let player = AVPlayer(playerItem: item)
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time: time, item: item) }
        }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
        self.player = player
        player.play()
    }

    private func tick(time: CMTime, item: AVPlayerItem) {
        let duration = item.duration.seconds
        let fraction = duration.isFinite && duration > 0 ? min(time.seconds / duration, 1) : 0
        progress = (Double(index) + fraction) / Double(queue.count)
    }

    private func advance() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        index += 1
        playCurrent()
    }

    /// Total length of the files, formatted as m:ss.
    static func duration(of urls: [URL]) async -> String? {
        var total = 0.0
        for url in urls {
            if let d = try? await AVURLAsset(url: url).load(.duration).seconds, d.isFinite { total += d }
        }
        guard total > 0 else { return nil }
        let seconds = Int(total.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
