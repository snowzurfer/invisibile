//
//  ContentView.swift
//  invisibile
//
//  Created by Alberto Taiuti in May 2023.
//

import SwiftUI
import SceneKit

let demoGIFFileName = "front_hair"

struct ContentView : View {
    @State private var videoUrl: URL?
    @State private var videoSize: CGSize?
    @State private var processing = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(videoUrl: videoUrl, videoSize: videoSize).edgesIgnoringSafeArea(.all)
            
            Button {
                guard let gifUrl = Bundle.main.url(forResource: demoGIFFileName, withExtension: "gif") else {
                    fatalError("Couldn't find the sample GIF")
                }
                
                Task {
                    processing = true
                    do {
                        let gifData = try Data(contentsOf: gifUrl)
                        let converter = try GIFToMOVConverter()
                        
                        let (resizedVideoSize, temporaryUrl) = try await converter.createVideo(from: gifData)
                        
                        // If in DEBUG mode, copy the result video to the Documents' directory so that it can
                        // be inspected via the Files app to check that the conversion happened correctly.
#if DEBUG
                        let documentsUrl = URL.documentsDirectory.appending(component: demoGIFFileName).appendingPathExtension(for: .quickTimeMovie)
                        print(documentsUrl)
                        let fm = FileManager.default
                        
                        // Copy the file from the temporary url to the documents directory, replacing it if it already exists.
                        if fm.fileExists(atPath: documentsUrl.path) {
                            try fm.removeItem(at: documentsUrl)
                        }
                        try fm.copyItem(at: temporaryUrl, to: documentsUrl)
#endif
                        
                        videoUrl = temporaryUrl
                        videoSize = resizedVideoSize
                    } catch {
                        print("Failed to convert: \(error.localizedDescription)")
                    }
                    
                    processing = false
                }
            } label: {
                Text("Convert GIF")
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .disabled(processing)
            
            if processing {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

final private class ARViewManager: ObservableObject {
    var scene: SCNScene?
    
    private var videoNode: SCNNode?
    
    func update(videoURL: URL, videoSize: CGSize) {
        guard let scene = scene else { return }
        
        if let existingNode = videoNode {
            existingNode.removeFromParentNode()
        }
        
        let newNode = makeVideoNode(videoURL: videoURL, videoSize: videoSize)
        scene.rootNode.addChildNode(newNode)
        videoNode = newNode
    }
    
    private func makeVideoNode(videoURL: URL, videoSize: CGSize) -> SCNNode {
        let aspectRatio = videoSize.width / videoSize.height
        let planeWidth: CGFloat = 0.5
        let planeHeight = planeWidth * aspectRatio
        
        let geom = SCNPlane(width: planeWidth, height: planeHeight)
        geom.firstMaterial!.lightingModel = .constant
        geom.firstMaterial!.isDoubleSided = true
        
        geom.firstMaterial!.diffuse.contents = VideoSpriteKitSCNNode(size: videoSize, videoToPlayURL: videoURL)
        
        let node = SCNNode(geometry: geom)
        
        return node
    }
}

struct ARViewContainer: UIViewRepresentable {
    let videoUrl: URL?
    let videoSize: CGSize?
    
    @StateObject private var manager = ARViewManager()
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.backgroundColor = .black.withAlphaComponent(0.9)
        
        let scene = SCNScene()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        
        manager.scene = scene
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let url = videoUrl, let size = videoSize else { return }
        manager.update(videoURL: url, videoSize: size)
    }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
