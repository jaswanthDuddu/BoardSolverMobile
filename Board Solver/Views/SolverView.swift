//
//  ContentView.swift
//  Board Solver
//
//  Created by Henry Robbins on 6/4/24.
//

import SwiftUI
import CoreML
import Vision
import RealityKit
import ARKit
import UIKit

struct SolverView: View
{
    @ObservedObject var FClassifier: ImageClassifier
    @Environment(\.dismiss) private var dismiss
    @State private var arView = ARView(frame: .zero)
    @State private var capturedImage: UIImage?
    @State var FBoardView: BoardView
    @State var playerColor: Int
    @Binding var FBoard: [[Int]]
    @State var FResultsBoard: [[Int]]
    @State private var isScanning = false
    @State private var isSolving = false
    @State var canSolve: Bool = false
    @Binding var game: String

    var body: some View
    {
        ZStack
        {
            ARViewContainer(arView: $arView)
                .edgesIgnoringSafeArea(.all)
            
            VStack
            {
                Spacer()
                
                if game == "four" {
                    FBoardView
                        .padding(.bottom, 20)
                } else if game == "scramble" {
                    Text("Scramble Board")
                }
                
                
                HStack{
                    Button
                    {
                        if game == "four" {
                            DispatchQueue.global().async
                            {
                                isScanning = true
                                withAnimation(){
                                    canSolve = true
                                    captureFrame()
                                    if let image = capturedImage
                                    {
                                        FResultsBoard = FClassifier.detect(uiImage: rotateImage90DegreesClockwise(image: image)!, playerColor: playerColor)
                                        $FBoardView.wrappedValue.updateBoard(brd: FResultsBoard)
                                        FBoardView.board = FResultsBoard
                                    }
                                }
                                isScanning = false
                            }
                        } else if game == "scramble" {
                            captureFrame()
                            if let image = capturedImage
                            {
                                
                                let imageData = image.jpegData(compressionQuality: 1)
                                let fileContent = imageData?.base64EncodedString()
                                let postData = fileContent!.data(using: .utf8)
                                
                                // Initialize Inference Server Request with API_KEY, Model, and Model Version
                                var request = URLRequest(url: URL(string: "https://classify.roboflow.com/scrabble-board/1?api_key=API_KEY_HERE&name=YOUR_IMAGE.jpg")!,timeoutInterval: Double.infinity)
                                request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                                request.httpMethod = "POST"
                                request.httpBody = postData
                                
                                // Execute Post Request
                                URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
                                    
                                    // Parse Response to String
                                    guard let data = data else {
                                        print(String(describing: error))
                                        return
                                    }
                                    
                                    // Convert Response String to Dictionary
                                    do {
                                        let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                                    } catch {
                                        print(error.localizedDescription)
                                    }
                                    
                                    // Print String Response
                                    print(String(data: data, encoding: .utf8)!)
                                }).resume()
                            }
                        }
                        
                    } label: {
                        Label("", image: "scan_prompt")
                    }
                    .frame(maxWidth: 175)
                   
                    Button
                    {
                        if game == "four" {
                            DispatchQueue.global().async
                            {
                                isSolving = true
                                withAnimation(){
                                    FResultsBoard = Board.startSolving(board: FBoard, playerColor: playerColor)
                                    $FBoardView.wrappedValue.updateBoard(brd: FResultsBoard)
                                    FBoardView.board = FResultsBoard
                                }
                                isSolving = false
                            }
                        } else if game == "scramble" {
                            print("solving for scramble")
                        }
                    } label: {
                        Label("", image: "solve_prompt")
                    }
                    .frame(maxWidth: 175)
                    .disabled(!canSolve)
                }
                .padding()
                
                Button {
                    dismiss()
                } label: {
                    Label("", image: "Back_prompt")
                }
                .frame(minWidth: 200)
            }
            .padding(.bottom, 50)

            ProgressView("Scanning")
                .progressViewStyle(CircularProgressViewStyle())
                .background(.white)
                .foregroundColor(.black)
                .opacity(isScanning ? 0.9 : 0)
                .frame(width: 150, height: 150)
            
            ProgressView("Solving")
                .progressViewStyle(CircularProgressViewStyle())
                .background(.white)
                .foregroundColor(.black)
                .opacity(isSolving ? 0.9 : 0)
                .frame(width: 150, height: 150)

        }
        .ignoresSafeArea(.all)
    }
    
    private func captureFrame()
    {
        let frame = arView.session.currentFrame
        let ciImage = CIImage(cvPixelBuffer: frame!.capturedImage)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            capturedImage = UIImage(cgImage: cgImage)
        }
    }
}

struct ARViewContainer: UIViewRepresentable
{
    @Binding var arView: ARView
    
    func makeUIView(context: Context) -> ARView {
        arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        arView.session.run(config)
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

func rotateImage90DegreesClockwise(image: UIImage) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }
    
    // Calculate the size of the rotated image
    let rotatedSize = CGSize(width: image.size.height, height: image.size.width)
    
    // Create a new bitmap context
    UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
    let context = UIGraphicsGetCurrentContext()
    
    // Move the origin to the middle of the image so we can rotate around the center.
    context?.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
    
    // Rotate the image context by 90 degrees clockwise
    context?.rotate(by: CGFloat.pi / 2)
    
    // Draw the image into the context
    context?.scaleBy(x: 1.0, y: -1.0)
    context?.draw(cgImage, in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
    
    // Get the rotated image from the context
    let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
    
    // Clean up the context
    UIGraphicsEndImageContext()
    
    return rotatedImage
}
