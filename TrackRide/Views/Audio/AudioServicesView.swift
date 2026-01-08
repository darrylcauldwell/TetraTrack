//
//  AudioServicesView.swift
//  TrackRide
//
//  Quick links to audio services during rides
//

import SwiftUI
import MediaPlayer
import MusicKit

// MARK: - Audio Services View

struct AudioServicesView: View {
    @State private var showingMusicPicker = false
    @State private var isPlaying = false
    @State private var nowPlayingTitle: String?
    private let player = MPMusicPlayerController.systemMusicPlayer

    let audioServices: [AudioService] = [
        AudioService(name: "Apple Music", icon: "music.note", color: .pink, urlScheme: "music://"),
        AudioService(name: "Audible", icon: "headphones", color: .orange, urlScheme: "audible://"),
        AudioService(name: "Spotify", icon: "speaker.wave.3", color: .green, urlScheme: "spotify://"),
        AudioService(name: "Podcasts", icon: "mic", color: .purple, urlScheme: "podcasts://"),
        AudioService(name: "Audiobooks", icon: "book", color: .cyan, urlScheme: "audiobooks://"),
        AudioService(name: "Overcast", icon: "antenna.radiowaves.left.and.right", color: .blue, urlScheme: "overcast://"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundStyle(AppColors.primary)
                Text("Audio")
                    .font(.headline)
            }

            // Now playing indicator
            if let title = nowPlayingTitle {
                HStack {
                    Image(systemName: isPlaying ? "waveform" : "pause.circle")
                        .foregroundStyle(isPlaying ? AppColors.active : .secondary)
                    Text(title)
                        .font(.caption)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
            }

            // Audio service buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(audioServices) { service in
                        AudioServiceButton(service: service)
                    }
                }
            }

            // Playback controls
            PlaybackControlsView()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            // Enable notifications from the music player
            player.beginGeneratingPlaybackNotifications()
            updateNowPlaying()
        }
        .onDisappear {
            player.endGeneratingPlaybackNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)) { _ in
            updateNowPlaying()
        }
        .onReceive(NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange)) { _ in
            updateNowPlaying()
        }
    }

    private func updateNowPlaying() {
        nowPlayingTitle = player.nowPlayingItem?.title
        isPlaying = player.playbackState == .playing
    }
}

// MARK: - Audio Service Model

struct AudioService: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let urlScheme: String

    var isInstalled: Bool {
        guard let url = URL(string: urlScheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    func open() {
        guard let url = URL(string: urlScheme),
              UIApplication.shared.canOpenURL(url) else {
            // Open App Store if not installed
            openAppStore()
            return
        }
        UIApplication.shared.open(url)
    }

    private func openAppStore() {
        let appStoreIDs: [String: String] = [
            "Apple Music": "1108187390",
            "Spotify": "324684580",
            "Podcasts": "525463029",
            "Overcast": "888422857",
            "Audiobooks": "1614007712",
            "Audible": "379693831"
        ]

        guard let appID = appStoreIDs[name],
              let url = URL(string: "itms-apps://apps.apple.com/app/id\(appID)") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Audio Service Button

struct AudioServiceButton: View {
    let service: AudioService

    var body: some View {
        Button(action: service.open) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(service.color.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: service.icon)
                        .font(.title3)
                        .foregroundStyle(service.color)
                }

                Text(service.name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .opacity(service.isInstalled ? 1.0 : 0.5)
    }
}

// MARK: - Playback Controls

struct PlaybackControlsView: View {
    @State private var isPlaying = false
    private let player = MPMusicPlayerController.systemMusicPlayer

    var body: some View {
        HStack(spacing: 24) {
            Button(action: previousTrack) {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }

            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(AppColors.primary.opacity(0.2))
                    .clipShape(Circle())
            }

            Button(action: nextTrack) {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
        }
        .foregroundStyle(AppColors.primary)
        .frame(maxWidth: .infinity)
        .onAppear {
            // Enable notifications from the music player
            player.beginGeneratingPlaybackNotifications()
            updatePlaybackState()
        }
        .onDisappear {
            player.endGeneratingPlaybackNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange)) { _ in
            updatePlaybackState()
        }
    }

    private func updatePlaybackState() {
        isPlaying = player.playbackState == .playing
    }

    private func togglePlayPause() {
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
        // Update state after a brief delay to allow player to respond
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            updatePlaybackState()
        }
    }

    private func previousTrack() {
        player.skipToPreviousItem()
    }

    private func nextTrack() {
        player.skipToNextItem()
    }
}

// MARK: - Compact Audio Controls (for use in tracking views)

// MARK: - Compact Music Button (Toolbar style)

struct CompactMusicButton: View {
    @State private var isPlaying = false
    @State private var showingFullControls = false
    private let player = MPMusicPlayerController.systemMusicPlayer

    var body: some View {
        Button(action: { showingFullControls = true }) {
            Image(systemName: isPlaying ? "music.note" : "music.note")
                .font(.body.weight(.medium))
                .foregroundStyle(isPlaying ? AppColors.primary : .primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay {
                    if isPlaying {
                        Circle()
                            .stroke(AppColors.primary, lineWidth: 2)
                    }
                }
        }
        .sheet(isPresented: $showingFullControls) {
            AudioControlsSheet()
                .presentationDetents([.medium])
        }
        .onAppear {
            player.beginGeneratingPlaybackNotifications()
            isPlaying = player.playbackState == .playing
        }
        .onDisappear {
            player.endGeneratingPlaybackNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange)) { _ in
            isPlaying = player.playbackState == .playing
        }
    }
}

// MARK: - Compact Audio Controls (Capsule style)

struct CompactAudioControls: View {
    @State private var isPlaying = false
    @State private var showingFullControls = false
    private let player = MPMusicPlayerController.systemMusicPlayer

    var body: some View {
        Button(action: { showingFullControls = true }) {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .foregroundStyle(AppColors.primary)

                if isPlaying {
                    // Animated waveform indicator
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(AppColors.primary)
                                .frame(width: 3, height: CGFloat.random(in: 8...16))
                        }
                    }
                } else {
                    Text("Music")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showingFullControls) {
            AudioControlsSheet()
                .presentationDetents([.medium])
        }
        .onAppear {
            // Enable notifications from the music player
            player.beginGeneratingPlaybackNotifications()
            isPlaying = player.playbackState == .playing
        }
        .onDisappear {
            player.endGeneratingPlaybackNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange)) { _ in
            isPlaying = player.playbackState == .playing
        }
    }
}

// MARK: - Audio Controls Sheet

struct AudioControlsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AudioServicesView()
                .padding()
                .navigationTitle("Audio")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    AudioServicesView()
        .padding()
}
