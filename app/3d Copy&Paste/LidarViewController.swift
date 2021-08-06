/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import Foundation
import RealityKit
import ARKit
import ModelIO
import MetalKit
import QuickLook
import VideoToolbox


class LidarViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet var arView: ARView!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var saveButton: RoundedButton!
    @IBOutlet weak var pasteButton: RoundedButton!
    @IBOutlet weak var hitBoxMarker: UIImageView!
    
    /// - Tag: ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.session.delegate = self

        arView.environment.sceneUnderstanding.options = []

        // Display a debug visualization of the mesh.
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        // For performance, disable render options that are not required for this app.
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        // Manually configure what kind of AR session to run
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        // detect planes
        configuration.planeDetection = [.horizontal, .vertical]

        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
        
        pasteButton.isEnabled = false
        hitBoxMarker.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        if let configuration = arView.session.configuration {
            arView.session.run(configuration, options: .resetSceneReconstruction)
            self.saveButton.isEnabled = true
            self.pasteButton.isEnabled = false
            hitBoxMarker.isHidden = true
            self.arView.debugOptions.insert(.showSceneUnderstanding)
        }
    }
    
    @IBAction func previewButtonPressed(_ sender: Any) {
        if let img = self.arView.session.currentFrame?.capturedImage {
            let ciimg = CIImage(cvImageBuffer: img)
            let finImage = UIImage(ciImage: ciimg)
            uploadImage(paramName: "data", fileName: "screen", image: finImage)
        }
    }
    
    func uploadImage(paramName: String, fileName: String, image: UIImage) {
        let url = URL(string: "http://192.168.2.3:8080/paste")

        // generate boundary string using a unique per-app string
        let boundary = UUID().uuidString

        let session = URLSession.shared

        // Set the URLRequest to POST and to the specified URL
        var urlRequest = URLRequest(url: url!)
        urlRequest.httpMethod = "POST"

        // Set Content-Type Header to multipart/form-data, this is equivalent to submitting form data with file upload in a web browser
        // And the boundary is also set here
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()

        // Add the image data to the raw http request data
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(paramName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        data.append(image.pngData()!)

        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        // Send a POST request to the URL, with the data we created earlier
        session.uploadTask(with: urlRequest, from: data, completionHandler: { responseData, response, error in
            if error == nil {
                let jsonData = try? JSONSerialization.jsonObject(with: responseData!, options: .allowFragments)
                if let json = jsonData as? [String: Any] {
                    print(json)
                }
            }
        }).resume()
    }
    
    /// - Tag: Export Mesh
    /// ***********************************************************************************************
    /// Exporting the LIDAR scan as a file
    @IBAction func saveButtonPressed(_ sender: UIButton) {
        print("Saving is executing...")
            
        guard let frame = arView.session.currentFrame
        else { fatalError("Can't get ARFrame") }
                
        guard let device = MTLCreateSystemDefaultDevice()
        else { fatalError("Can't create MTLDevice") }
        
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(bufferAllocator: allocator)
        let meshAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        
        for ma in meshAnchors {
            let geometry = ma.geometry
            let vertices = geometry.vertices
            let faces = geometry.faces
            let vertexPointer = vertices.buffer.contents()
            let facePointer = faces.buffer.contents()
            
            for vtxIndex in 0 ..< vertices.count {
                
                let vertex = geometry.vertex(at: UInt32(vtxIndex))
                var vertexLocalTransform = matrix_identity_float4x4
                
                vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.0,
                                                              y: vertex.1,
                                                              z: vertex.2,
                                                              w: 1.0)
                
                let vertexWorldTransform = (ma.transform * vertexLocalTransform).position
                let vertexOffset = vertices.offset + vertices.stride * vtxIndex
                let componentStride = vertices.stride / 3
                
                vertexPointer.storeBytes(of: vertexWorldTransform.x,
                               toByteOffset: vertexOffset,
                                         as: Float.self)
                
                vertexPointer.storeBytes(of: vertexWorldTransform.y,
                               toByteOffset: vertexOffset + componentStride,
                                         as: Float.self)
                
                vertexPointer.storeBytes(of: vertexWorldTransform.z,
                               toByteOffset: vertexOffset + (2 * componentStride),
                                         as: Float.self)
            }
            
            let byteCountVertices = vertices.count * vertices.stride
            let byteCountFaces = faces.count * faces.indexCountPerPrimitive * faces.bytesPerIndex
            
            let vertexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: vertexPointer,
                                                                    count: byteCountVertices,
                                                              deallocator: .none), type: .vertex)
            
            let indexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: facePointer,
                                                                   count: byteCountFaces,
                                                             deallocator: .none), type: .index)
            
            let indexCount = faces.count * faces.indexCountPerPrimitive
            let material = MDLMaterial(name: "material",
                         scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
            
            let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                      indexCount: indexCount,
                                       indexType: .uInt32,
                                    geometryType: .triangles,
                                        material: material)
            
            let vertexFormat = MTKModelIOVertexFormatFromMetal(vertices.format)
            
            let vertexDescriptor = MDLVertexDescriptor()
            
            vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                              format: vertexFormat,
                                                              offset: 0,
                                                         bufferIndex: 0)
            
            vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: ma.geometry.vertices.stride)
            
            let mesh = MDLMesh(vertexBuffer: vertexBuffer,
                                vertexCount: ma.geometry.vertices.count,
                                 descriptor: vertexDescriptor,
                                  submeshes: [submesh])

            asset.add(mesh)
        }

        let filePath = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        
        let urlObj: URL = filePath.appendingPathComponent("model.obj")

        if MDLAsset.canExportFileExtension("obj") {
            do {
                try asset.export(to: urlObj)
                
                let controller = UIActivityViewController(activityItems: [urlObj],
                                                  applicationActivities: nil)
                controller.popoverPresentationController?.sourceView = sender
                self.present(controller, animated: true, completion: nil)
                controller.completionWithItemsHandler  = { activityType, completed, items, error in
                    if !completed {
                        // handle task not completed
                        return
                    }
                    if activityType == .airDrop {
                        print(" > 3D model shared")
                        self.pasteButton.isEnabled = true
                        self.saveButton.isEnabled = false
                        self.hitBoxMarker.isHidden = false
                        self.arView.debugOptions.remove(.showSceneUnderstanding)
                    }
                }
            } catch let error {
                fatalError(error.localizedDescription)
            }
        } else {
            fatalError("Can't export USD")
        }
    }
    /// ***********************************************************************************************

    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetButtonPressed(self)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
}
