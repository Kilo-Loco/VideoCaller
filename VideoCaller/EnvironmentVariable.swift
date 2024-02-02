//
//  EnvironmentVariable.swift
//  VideoCaller
//
//  Created by Kilo Loco on 2/1/24.
//

import Foundation

enum EnvironmentVariable: String {
    case agoraAppId = "AGORA_APP_ID"
    case agoraRtcToken = "AGORA_RTC_TOKEN"
    
    var value: String {
        ProcessInfo.processInfo.environment[rawValue]!
    }
}
