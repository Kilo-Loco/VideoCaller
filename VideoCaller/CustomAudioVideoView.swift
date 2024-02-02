//
//  CustomAudioVideoView.swift
//  VideoCaller
//
//  Created by Kilo Loco on 2/1/24.
//

import AVKit
import SwiftUI

struct CustomAudioVideoView: View {
    @ObservedObject var agoraManager: CustomAudioVideoManager
    var customPreview = CustomVideoSourcePreview()

    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    AgoraCustomVideoCanvasView(
                        canvas: customPreview, previewLayer: agoraManager.previewLayer
                    ).aspectRatio(contentMode: .fit).cornerRadius(10)
                    ForEach(Array(agoraManager.allUsers), id: \.self) { uid in
                        AgoraVideoCanvasView(manager: agoraManager, uid: uid)
                            .aspectRatio(contentMode: .fit).cornerRadius(10)
                    }
                }.padding(20)
            }
        }.task {
            await agoraManager.joinChannel("main")
        }.onDisappear {
            agoraManager.leaveChannel()
        }
    }
    
    init() {
        let microphone = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices.first!
        
        self.agoraManager = CustomAudioVideoManager(
            appId: EnvironmentVariable.agoraAppId.value, 
            role: .broadcaster,
            videoCaptureDevice: .systemPreferredCamera!,
            audioCaptureDevice: microphone
        )
    }
}

