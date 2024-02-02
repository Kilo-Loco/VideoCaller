//
//  WhisperKitClient.swift
//  VideoCaller
//
//  Created by Kilo Loco on 2/1/24.
//

import AVFoundation
import Foundation
import WhisperKit

final class WhisperKitClient: ObservableObject {
    private var transcriptionTask: Task<Void, Never>? = nil
    private var isRecording: Bool = false
    private var isTranscribing: Bool =  false
    private var lastBufferSize: Int = 0
    private var lastConfirmedSegmentEndSeconds: Float = 0
    private var bufferEnergy: [Float] = []
    
    private var whisper: WhisperKit!
    
    init() {
        Task {
            do {
                self.whisper = try await WhisperKit()
            } catch {
                fatalError("Something broke")
            }
        }
    }
    
    // MARK: Streaming Logic

    func realtimeLoop() {
        transcriptionTask = Task {
            while isRecording && isTranscribing {
                do {
                    try await transcribeCurrentBuffer()
                } catch {
                    print("Error: \(error.localizedDescription)")
                    break
                }
            }
        }
    }

    func stopRealtimeTranscription() {
        isTranscribing = false
        transcriptionTask?.cancel()
    }

    func transcribeCurrentBuffer() async throws {
        guard let whisper else { return }

        // Retrieve the current audio buffer from the audio processor
        let currentBuffer = whisper.audioProcessor.audioSamples

        // Calculate the size and duration of the next buffer segment
        let nextBufferSize = currentBuffer.count - lastBufferSize
        let nextBufferSeconds = Float(nextBufferSize) / Float(WhisperKit.sampleRate)

        // Only run the transcribe if the next buffer has at least 1 second of audio
        guard nextBufferSeconds > 1 else {
            try await Task.sleep(nanoseconds: 100_000_000) // sleep for 100ms for next buffer
            return
        }

        // Run transcribe
        lastBufferSize = currentBuffer.count


        let transcription = try await whisper.transcribe(audioArray: Array(currentBuffer))

        
    }
    
    func startRecording(_ loop: Bool) {
        if let audioProcessor = whisper?.audioProcessor {
            Task(priority: .userInitiated) {
                
                try? audioProcessor.startRecordingLive { [weak self] buffer in
                    DispatchQueue.main.async { [weak self] in
                        self?.bufferEnergy = self?.whisper?.audioProcessor.relativeEnergy ?? []
                    }
                }

                // Delay the timer start by 1 second
                isRecording = true
                isTranscribing = true
                if loop {
                    realtimeLoop()
                }
            }
        }
    }
    
}
