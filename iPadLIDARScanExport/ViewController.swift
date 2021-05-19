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


class ViewController: UIViewController, ARSessionDelegate, QLPreviewControllerDataSource {
    
    @IBOutlet var arView: ARView!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var saveButton: RoundedButton!
    @IBOutlet weak var previewButton: RoundedButton!
    
    let coachingOverlay = ARCoachingOverlayView()
    let previewController = QLPreviewController()
    
    /// - Tag: ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.session.delegate = self
        
        setupCoachingOverlay()

        arView.environment.sceneUnderstanding.options = []
        
        // Turn on occlusion from the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        
        // Turn on physics for the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.physics)

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
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // set quicklook
        previewController.dataSource = self
    }
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { return 1 }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        guard let path = Bundle.main.path(forResource: "toy_robot_vintage", ofType: "usdz") else { fatalError("Couldn't find the supported input file.") }
        
        print(path)
        let url = URL(fileURLWithPath: path)
        return url as QLPreviewItem
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        if let configuration = arView.session.configuration {
            arView.session.run(configuration, options: .resetSceneReconstruction)
        }
    }
    
    @IBAction func previewButtonPressed(_ sender: Any) {
        present(previewController, animated: true, completion: nil)
    }
    
    @IBAction func saveButtonPressed(_ sender: UIButton) {
        let mesh = MeshResource.generateBox(size: 0.2)
        let material = SimpleMaterial(color: .blue, roughness: 0.5, isMetallic: true)
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        
        guard let currentFrame = arView.session.currentFrame else  { return }
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.5
        let transform = currentFrame.camera.transform
        let rotation = matrix_float4x4(SCNMatrix4MakeRotation(Float.pi/2, 0, 0, 1))
        let anchorTransform = matrix_multiply(transform, matrix_multiply(translation, rotation))

        let anchorEntity = AnchorEntity(world: anchorTransform)
        anchorEntity.addChild(modelEntity)
        
        arView.scene.addAnchor(anchorEntity)
        
        modelEntity.generateCollisionShapes(recursive: true)
        
        arView.installGestures([.rotation, .scale], for: modelEntity)
    }
    
    /// - Tag: Export Mesh
    /// ***********************************************************************************************
    /// Exporting the LIDAR scan as OBJ file
    /*
    @IBAction func saveButtonPressed(_ sender: UIButton) {
        
        guard let frame = arView.session.currentFrame else {
            fatalError("Couldn't get the current ARFrame")
        }
        
        // Fetch the default MTLDevice to initialize a MetalKit buffer allocator with
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to get the system's default Metal device!")
        }
        
        // Using the Model I/O framework to export the scan, so we're initialising an MDLAsset object,
        // which we can export to a file later, with a buffer allocator
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(bufferAllocator: allocator)
        
        // Fetch all ARMeshAncors
        let meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
        
        // Convert the geometry of each ARMeshAnchor into a MDLMesh and add it to the MDLAsset
        for meshAncor in meshAnchors {
            
            // Some short handles, otherwise stuff will get pretty long in a few lines
            let geometry = meshAncor.geometry
            let vertices = geometry.vertices
            let faces = geometry.faces
            let verticesPointer = vertices.buffer.contents()
            let facesPointer = faces.buffer.contents()
            
            // Converting each vertex of the geometry from the local space of their ARMeshAnchor to world space
            for vertexIndex in 0..<vertices.count {
                
                // Extracting the current vertex with an extension method provided by Apple in Extensions.swift
                let vertex = geometry.vertex(at: UInt32(vertexIndex))
                
                // Building a transform matrix with only the vertex position
                // and apply the mesh anchors transform to convert into world space
                var vertexLocalTransform = matrix_identity_float4x4
                vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.0, y: vertex.1, z: vertex.2, w: 1)
                let vertexWorldPosition = (meshAncor.transform * vertexLocalTransform).position
                
                // Writing the world space vertex back into it's position in the vertex buffer
                let vertexOffset = vertices.offset + vertices.stride * vertexIndex
                let componentStride = vertices.stride / 3
                verticesPointer.storeBytes(of: vertexWorldPosition.x, toByteOffset: vertexOffset, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.y, toByteOffset: vertexOffset + componentStride, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.z, toByteOffset: vertexOffset + (2 * componentStride), as: Float.self)
            }
            
            // Initializing MDLMeshBuffers with the content of the vertex and face MTLBuffers
            let byteCountVertices = vertices.count * vertices.stride
            let byteCountFaces = faces.count * faces.indexCountPerPrimitive * faces.bytesPerIndex
            let vertexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: verticesPointer, count: byteCountVertices, deallocator: .none), type: .vertex)
            let indexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: facesPointer, count: byteCountFaces, deallocator: .none), type: .index)
            
            // Creating a MDLSubMesh with the index buffer and a generic material
            let indexCount = faces.count * faces.indexCountPerPrimitive
            let material = MDLMaterial(name: "mat1", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
            let submesh = MDLSubmesh(indexBuffer: indexBuffer, indexCount: indexCount, indexType: .uInt32, geometryType: .triangles, material: material)
            
            // Creating a MDLVertexDescriptor to describe the memory layout of the mesh
            let vertexFormat = MTKModelIOVertexFormatFromMetal(vertices.format)
            let vertexDescriptor = MDLVertexDescriptor()
            vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: vertexFormat, offset: 0, bufferIndex: 0)
            vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: meshAncor.geometry.vertices.stride)
            
            // Finally creating the MDLMesh and adding it to the MDLAsset
            let mesh = MDLMesh(vertexBuffer: vertexBuffer, vertexCount: meshAncor.geometry.vertices.count, descriptor: vertexDescriptor, submeshes: [submesh])
            asset.add(mesh)
        }
        
        // Setting the path to export the OBJ file to
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlOBJ = documentsPath.appendingPathComponent("scan.obj")

        // Exporting the OBJ file
        if MDLAsset.canExportFileExtension("obj") {
            do {
                try asset.export(to: urlOBJ)
                
                // Sharing the OBJ file
                let activityController = UIActivityViewController(activityItems: [urlOBJ], applicationActivities: nil)
                activityController.popoverPresentationController?.sourceView = sender
                self.present(activityController, animated: true, completion: nil)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        } else {
            fatalError("Can't export OBJ")
        }
    }*/
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
