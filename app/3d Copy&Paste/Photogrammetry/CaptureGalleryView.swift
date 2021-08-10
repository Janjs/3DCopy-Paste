import Combine
import Foundation
import SwiftUI
import Alamofire

let urlServer = "http://192.168.1.150:8080/photogrammetry"

/// This view displays the contents of a capture directory.
struct CaptureGalleryView: View {
    private let columnSpacing: CGFloat = 3
    
    /// This is the data model the capture session uses.
    @ObservedObject var model: CameraViewModel
    
    /// This property holds the folder the user is currently viewing.
    @ObservedObject private var captureFolderState: CaptureFolderState
    
    /// When a thumbnail cell is tapped, this property holds the information about the tapped image.
    @State var zoomedCapture: CaptureInfo? = nil
    @State var pasteButtonEnabled: Bool = false
    @State var copyButtonEnabled: Bool = true
    @State private var showingSheet = false
    
    /// When this is set to `true`, the app displays a toolbar button to dispays the capture folder.
    @State private var showCaptureFolderView: Bool = false
    
    /// This property indicates whether the app is currently displaying the capture folder for the live session.
    let usingCurrentCaptureFolder: Bool
    
    /// This array defines the vertical layout for portrait orientation.
    let portraitLayout: [GridItem] = [ GridItem(.flexible()),
                                       GridItem(.flexible()),
                                       GridItem(.flexible()) ]
    
    /// This initializer creates a capture gallery view for the active capture session.
    init(model: CameraViewModel) {
        self.model = model
        self.captureFolderState = model.captureFolderState!
        usingCurrentCaptureFolder = true
    }
    
    /// This initializer creates a capture gallery view for a previously created capture folder.
    init(model: CameraViewModel, observing captureFolderState: CaptureFolderState) {
        self.model = model
        self.captureFolderState = captureFolderState
        usingCurrentCaptureFolder = (model.captureFolderState?.captureDir?.lastPathComponent
                                        == captureFolderState.captureDir?.lastPathComponent)
    }
    
    var body: some View {
        ZStack {
            Color(red: 0, green: 0, blue: 0.01, opacity: 1).ignoresSafeArea(.all)
            
            // Create a hidden navigation link for the toolbar item.
            NavigationLink(destination: CaptureFoldersView(model: model),
                           isActive: self.$showCaptureFolderView) {
                EmptyView()
            }
            .frame(width: 0, height: 0)
            .disabled(true)
            
            VStack {
                GeometryReader { geometryReader in
                    ScrollView() {
                        LazyVGrid(columns: portraitLayout, spacing: columnSpacing) {
                            ForEach(captureFolderState.captures, id: \.id) { captureInfo in
                                GalleryCell(captureInfo: captureInfo,
                                            cellWidth: geometryReader.size.width / 3,
                                            cellHeight: geometryReader.size.width / 3,
                                            zoomedCapture: $zoomedCapture)
                            }
                        }
                    }
                }
                .blur(radius: zoomedCapture != nil ? 20 : 0)
                
                HStack {
                    Spacer()
                    Button(action: copyButtonPressed) {
                           Text("Copy")
                            .padding()
                            .background(copyButtonEnabled ? Color.blue : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .foregroundColor(Color.white)
                            .disabled(!copyButtonEnabled)
                       }
                    Spacer()
                    Button(action: pasteButtonPressed) {
                           Text("Paste")
                            .padding()
                            .background(pasteButtonEnabled ? Color.blue : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .foregroundColor(Color.white)
                            .disabled(!pasteButtonEnabled)
                       }
                    Spacer()
                }
            }
            
            if zoomedCapture != nil {
                ZStack(alignment: .top) {
                    // Add a transluscent layer over the blur to make the text pop.
                    Color(red: 0.25, green: 0.25, blue: 0.25, opacity: 0.25)
                        .ignoresSafeArea(.all)
                    
                    VStack {
                        FullSizeImageView(captureInfo: zoomedCapture!)
                            .onTapGesture {
                                zoomedCapture = nil
                            }
                    }
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            captureFolderState.removeCapture(captureInfo: zoomedCapture!,
                                                             deleteData: true)
                            zoomedCapture = nil
                        }) {
                            Text("Delete").foregroundColor(Color.red)
                        }.padding()
                    }
                }
            }
        }
        .navigationTitle(Text("\(captureFolderState.captureDir?.lastPathComponent ?? "NONE")"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: HStack {
            NewSessionButtonView(model: model, usingCurrentCaptureFolder: usingCurrentCaptureFolder)
                .padding(.horizontal, 5)
            if usingCurrentCaptureFolder {
                Button(action: {
                    self.showCaptureFolderView = true
                }) {
                    Image(systemName: "folder")
                }
            }
        })
        
        .sheet(isPresented: $showingSheet) {
            SheetView()
        }
    }
    
    func copyButtonPressed(){
        //copyButtonEnabled = false
        showingSheet.toggle()
        print("Copy")
        generate3DModel(captureFolderState: captureFolderState)
        print(copyButtonEnabled)
    }

    func pasteButtonPressed(){
        print("Paste")
    }
}

func generate3DModel(captureFolderState: CaptureFolderState) {
    let url = URL(string: "\(urlServer)/removebg")

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

    // Add the images data to the raw http request data
    data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"\("data[]")\"; filename=\"\(captureFolderState.captureDir?.lastPathComponent ?? "NONE")\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
    // Add image data
    for capture in captureFolderState.captures {
        do {
            let image = try ImageLoader.loadImageSynchronously(url: capture.imageUrl)
            data.append(image.pngData()!)
        } catch {
            print(error.localizedDescription)
        }
    }
    
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

struct SheetView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Text("Generating 3D model...")
        Button("Press to dismiss") {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct NewSessionButtonView: View {
    @ObservedObject var model: CameraViewModel
    
    /// This is an environment variable that the capture gallery view uses to store state.
    @Environment(\.presentationMode) private var presentation
    
    var usingCurrentCaptureFolder: Bool = true
    
    var body: some View {
        // Only show the new session if the user is viewing the current
        // capture directory.
        if usingCurrentCaptureFolder {
            Menu(content: {
                Button(action: {
                    model.requestNewCaptureFolder()
                    // Navigate back to the main scan page.
                    presentation.wrappedValue.dismiss()
                }) {
                    Label("New Session", systemImage: "camera")
                }
            }, label: {
                Image(systemName: "plus.circle")
            })
        }
    }
}

/// This cell displays a single thumbnail image with its metadata annotated on it.
struct GalleryCell: View {
    /// This property stores the location of the image and its metadata.
    let captureInfo: CaptureInfo
    
    /// When the user taps a cell to zoom in, this property contains the tapped cell's `captureInfo`.
    @Binding var zoomedCapture: CaptureInfo?
    
    /// This property keeps track of whether the image's metadata files exist. The app populates this
    /// property asynchronously.
    @State private var existence: CaptureInfo.FileExistence = CaptureInfo.FileExistence()
    
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    
    // This property holds a reference for a subscription to the `existence` future.
    var publisher: AnyPublisher<CaptureInfo.FileExistence, Never>
    
    init(captureInfo: CaptureInfo, cellWidth: CGFloat, cellHeight: CGFloat,
         zoomedCapture: Binding<CaptureInfo?>) {
        self.captureInfo = captureInfo
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        self._zoomedCapture = zoomedCapture
        
        // Make a single publisher for the metadata future.
        publisher = captureInfo.checkFilesExist()
            .receive(on: DispatchQueue.main)
            .replaceError(with: CaptureInfo.FileExistence())
            .eraseToAnyPublisher()
    }
    
    var body : some View {
        ZStack {
            AsyncThumbnailView(url: captureInfo.imageUrl)
                .frame(width: cellWidth, height: cellHeight)
                .clipped()
                .onTapGesture {
                    withAnimation {
                        self.zoomedCapture = captureInfo
                    }
                }
                .onReceive(publisher, perform: { loadedExistence in
                    existence = loadedExistence
                })
            MetadataExistenceSummaryView(existence: existence)
                .font(.caption)
                .padding(.all, 2)
        }
    }
}

struct MetadataExistenceSummaryView: View {
    var existence: CaptureInfo.FileExistence
    private let paddingPixels: CGFloat = 2
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                if existence.depth && existence.gravity {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.green)
                        .padding(.all, paddingPixels)
                } else if existence.depth || existence.gravity {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Color.yellow)
                        .padding(.all, paddingPixels)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.red)
                        .padding(.all, paddingPixels)
                }
                Spacer()
            }
        }
    }
}

struct MetadataExistenceView: View {
    var existence: CaptureInfo.FileExistence
    var textLabels: Bool = false
    
    var body: some View {
        HStack {
            if existence.depth {
                Image(systemName: "square.3.stack.3d.top.fill")
                    .foregroundColor(Color.green)
            } else {
                Image(systemName: "xmark.circle")
                    .foregroundColor(Color.red)
            }
            if textLabels {
                Text("Depth")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if existence.gravity {
                Image(systemName: "arrow.down.to.line.alt")
                    .foregroundColor(Color.green)
            } else {
                Image(systemName: "xmark.circle")
                    .foregroundColor(Color.red)
            }
            if textLabels {
                Text("Gravity")
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// This is the view the app shows when the user taps on a `GalleryCell` thumbnail. It asynchronously
/// loads the full-size image and displays it full-screen.
struct FullSizeImageView: View {
    let captureInfo: CaptureInfo
    var publisher: AnyPublisher<CaptureInfo.FileExistence, Never>
    
    @State private var existence = CaptureInfo.FileExistence()
    
    init(captureInfo: CaptureInfo) {
        self.captureInfo = captureInfo
        publisher = captureInfo.checkFilesExist()
            .receive(on: DispatchQueue.main)
            .replaceError(with: CaptureInfo.FileExistence())
            .eraseToAnyPublisher()
    }
    
    var body: some View {
        VStack {
            Text(captureInfo.imageUrl.lastPathComponent)
                .font(.caption)
                .padding()
            GeometryReader { geometryReader in
                AsyncImageView(url: captureInfo.imageUrl)
                    .frame(width: geometryReader.size.width, height: geometryReader.size.height)
                    .aspectRatio(contentMode: .fit)
            }
            MetadataExistenceView(existence: existence, textLabels: true)
                .onReceive(publisher, perform: { loadedExistence in
                    existence = loadedExistence
                })
                .padding(.all)
        }
        .transition(.opacity)
    }
}
