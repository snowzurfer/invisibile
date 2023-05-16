//
//  VideoSpriteKitSceneNode.swift
//  invisibile
//
//  Created by Alberto Taiuti in May 2023.
//

import AVFoundation
import SceneKit
import SpriteKit

final public class VideoSpriteKitSCNNode: SKScene {
    private let videoToPlayURL: URL
    private var avPlayer: AVPlayer!
    private var loopingToken: NSObjectProtocol?
    
    /// size: size in points
    public init(size: CGSize, videoToPlayURL: URL) {
        self.videoToPlayURL = videoToPlayURL
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let token = loopingToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    public override func sceneDidLoad() {
        super.sceneDidLoad()
        
        backgroundColor = .clear
        
        avPlayer = AVPlayer(url: videoToPlayURL)
        let videoNode = SKVideoNode(avPlayer: avPlayer)
        videoNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        videoNode.size = size
        videoNode.zRotation = .pi
        videoNode.xScale = -1
        
        addChild(videoNode)
        
        loopingToken = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: avPlayer.currentItem, queue: nil) { (notification) in
            self.avPlayer.seek(to: CMTime.zero)
            self.avPlayer.play()
        }
        
        avPlayer.play()
    }
}

