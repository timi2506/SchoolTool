import SwiftUI
import PDFKit
import UniformTypeIdentifiers
#if os(iOS)
import Drops
#endif

struct PDFToolView: View {
    @State var selectedURL: URL?
    @State var isPresenting = false
    @State var errorMsg: String?
    @State var results: [PDFImageResult] = []
    @State var quickLookItem: URL?
    @State var saveAllResults = false
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Text("You can use this tool to Extract Pages from a PDF as PNG")
                        .foregroundStyle(.secondary)
                    if let message = errorMsg {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                    if results.isEmpty {
                        HStack {
                            Spacer()
                            ContentUnavailableView("No Results yet", systemImage: "document")
                            Spacer()
                        }
                    } else {
                        #if os(iOS)
                        VStack(alignment: .leading) {
                            Toggle("Save to Photo Library", isOn: $saveToPhotos)
                            Text("If turned on, Photos will be saved to the Photos Library instead of the Files App")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        #endif
                        Section("Results") {
                            ForEach(results) { result in
                                PDFResultRow(result: result, quickLookItem: $quickLookItem, errorMsg: $errorMsg) {
                                    results.removeAll(where: { $0.id == result.id })
                                }
                            }
                            .onDelete { offsets in
                                results.remove(atOffsets: offsets)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .dropDestination(for: URL.self) { items, session in
                    if items.first?.pathExtension == "pdf" {
                        selectedURL = items.first
                        return true
                    } else {
                        #if os(iOS)
                        let drop = Drop.init(title: "Error", subtitle: "The Dropped File is not a PDF", icon: UIImage(systemName: "xmark"), action: Drop.Action { Drops.hideCurrent() }, position: .top)
                        Drops.show(drop)
                        #endif
                        return false
                    }
                }
            }
            .toolbar {
                Button(action: {
                    errorMsg = nil
                    isPresenting.toggle()
                }) {
                    Label("Select PDF", systemImage: "plus")
                }
                Button(action: {
                    saveAllResults.toggle()
                }) {
                    Label("Save All Results", systemImage: "square.and.arrow.down")
                }
            }
            .fileImporter(isPresented: $isPresenting, allowedContentTypes: [.pdf]) { result in
                do {
                    let url = try result.get()
                    _ = url.startAccessingSecurityScopedResource()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        selectedURL = url
                    }
                } catch {
                    errorMsg = error.localizedDescription
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedURL != nil },
                set: { newValue in if !newValue { selectedURL = nil } }
            )) {
                PDFPageSelectionView(pdfURL: selectedURL!) { result in
                    onSelection(result)
                }
            }
            .sheet(isPresented: $saveAllResults) {
                saveAllResultsView
            }
            .quickLookPreview($quickLookItem)
            .navigationTitle("PDF Tool")
        }
    }
    func onSelection(_ result: [PDFImageResult]) {
        let savedURL = selectedURL
        selectedURL = nil
        savedURL?.stopAccessingSecurityScopedResource()
        for thing in result {
            if !results.contains(where: { $0.data == thing.data && $0.documentName == thing.documentName && thing.name == $0.name }) {
                results.append(thing)
            }
        }
    }
    @State var deleteResultsAfterSaving = false
    @State var selectedResults: [PDFImageResult] = []
    var saveAllResultsView: some View {
        NavigationStack {
            VStack {
                Form {
                    Toggle("Delete from Results after saving", isOn: $deleteResultsAfterSaving)
                    Section("Select All Results you want to Save") {
                        if results.isEmpty {
                            HStack {
                                Spacer()
                                ContentUnavailableView("No Results yet", systemImage: "document")
                                Spacer()
                            }
                        }
                        
                        
                        ForEach(results) { result in
                            HStack {
#if os(macOS)
                                let nsImage: NSImage = {
                                    if let img = NSImage(data: result.data) { return img }
                                    return NSImage(systemSymbolName: "questionmark", accessibilityDescription: nil) ?? NSImage()
                                }()
                                A4ImageView(Image(nsImage: nsImage), size: CGSize(width: 35.5, height: 50), cornerRadius: 5)
#elseif os(iOS)
                                let uiImage: UIImage = {
                                    if let img = UIImage(data: result.data) { return img }
                                    return UIImage(systemName: "questionmark") ?? UIImage()
                                }()
                                A4ImageView(Image(uiImage: uiImage), size: CGSize(width: 35.5, height: 50), cornerRadius: 5)
#endif
                                VStack(alignment: .leading) {
                                    Text(result.name)
                                        .bold()
                                    Text(result.documentName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedResults.contains(result) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(selectedResults.contains(result) ? .accentColor : .gray)
                            }
                            .contentShape(.rect)
                            .onTapGesture {
                                if selectedResults.contains(result) {
                                    selectedResults.removeAll(where: { $0 == result })
                                } else {
                                    selectedResults.append(result)
                                }
                            }
                        }
                        .onDelete { offsets in
                            results.remove(atOffsets: offsets)
                        }
                    }
                }
                .formStyle(.grouped)
                HStack {
                    Button(action: { selectedResults = results }) { Text("Select All") }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    Button(action: { selectedResults.removeAll() }) { Text("Deselect All") }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    Spacer()
                    Button(action: {
                        if selectedResults.isEmpty {
                            saveAllResults = false
                        } else {
                            saveResult()
                        }
                    }) {
                        Text("Done")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)

                }
                .padding(10)
            }
            .navigationTitle("Save Results")
#if os(iOS)
            .fileMover(isPresented: Binding(get: { iosFiles != nil }, set: { _ = $0 }), files: iosFiles ?? []) { result in
                do {
                    let gottenResults = try result.get()
                    for gottenResult in gottenResults {
                        print(gottenResult.absoluteString)
                    }
                } catch {
                    errorMsg = error.localizedDescription
                }
                iosFiles = nil
            }
#endif
        }
    }
#if os(iOS)
    @State var iosFiles: [URL]?
    @AppStorage("saveToPhotos") var saveToPhotos = true
#endif
    func saveResult() {
#if os(macOS)
        if !selectedResults.isEmpty {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Select Folder to Save"
            if panel.runModal() == .OK, let url = panel.url {
                for result in selectedResults {
                    let name = result.name
                    let docName = result.documentName.replacingOccurrences(of: ".png", with: "")
                    let fileName = "\(docName) - \(name)"
                    let saveURL = url.appendingPathComponent(fileName, conformingTo: .png)
                    do {
                        try result.data.write(to: saveURL)
                        if deleteResultsAfterSaving {
                            results.removeAll(where: { $0 == result })
                        }
                    } catch {
                        if errorMsg == nil {
                            errorMsg = error.localizedDescription
                        } else {
                            errorMsg = "\(errorMsg ?? "")\n\(error.localizedDescription)"
                        }
                    }
                }
            }
            selectedResults = []
        }
#elseif os(iOS)
        var iosFileResults: [URL] = []
        for result in selectedResults {
            let freshTempDir = URL.temporaryDirectory.appendingPathComponent("temp_\(Date().timeIntervalSince1970)", conformingTo: .folder)
            try? FileManager.default.createDirectory(at: freshTempDir, withIntermediateDirectories: true)
            
            if saveToPhotos {
                if let img = UIImage(data: result.data) {
                    ImageSaver().writeToAlbum(image: img)
                }
                
            } else {
                let name = result.name
                let docName = result.documentName.replacingOccurrences(of: ".png", with: "")
                let fileName = "\(docName) - \(name)"
                let saveURL = freshTempDir.appendingPathComponent(fileName, conformingTo: .png)
                do {
                    try result.data.write(to: saveURL)
                    iosFileResults.append(saveURL)
                    if deleteResultsAfterSaving {
                        results.removeAll(where: { $0 == result })
                    }
                } catch {
                    if errorMsg == nil {
                        errorMsg = error.localizedDescription
                    } else {
                        errorMsg = "\(errorMsg ?? "")\n\(error.localizedDescription)"
                    }
                }
            }
        }
        if !saveToPhotos {
            iosFiles = iosFileResults
        }
#endif
    }
}

#if os(iOS)
class ImageSaver: NSObject {
    func writeToAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }
    
    @objc private func saveCompleted(_ image: UIImage,
                                     didFinishSavingWithError error: Error?,
                                     contextInfo: UnsafeRawPointer?) {
        if let error = error {
            Drops.hideAll()
            let drop = Drop.init(title: "Save failed", subtitle: "An Error occured saving the Image", icon: UIImage(systemName: "xmark"), action: Drop.Action { Drops.hideCurrent() }, position: .top)
            Drops.show(drop)
            print("❌ Save failed:", error.localizedDescription)
        } else {
            Drops.hideAll()
            let drop = Drop.init(title: "Save succeeded", subtitle: "The Image was saved successfully", icon: UIImage(systemName: "checkmark"), action: Drop.Action { Drops.hideCurrent() }, position: .top)
            Drops.show(drop)
            print("✅ Save succeeded!")
        }
    }
}
#endif

private struct PDFResultRow: View {
    let result: PDFImageResult
    @Binding var quickLookItem: URL?
    @Binding var errorMsg: String?
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
#if os(macOS)
            let nsImage: NSImage = {
                if let img = NSImage(data: result.data) { return img }
                return NSImage(systemSymbolName: "questionmark", accessibilityDescription: nil) ?? NSImage()
            }()
            A4ImageView(Image(nsImage: nsImage), size: CGSize(width: 35.5, height: 50), cornerRadius: 5)
#elseif os(iOS)
            let uiImage: UIImage = {
                if let img = UIImage(data: result.data) { return img }
                return UIImage(systemName: "questionmark") ?? UIImage()
            }()
            A4ImageView(Image(uiImage: uiImage), size: CGSize(width: 35.5, height: 50), cornerRadius: 5)
#endif
            VStack(alignment: .leading) {
                Text(result.name)
                    .bold()
                Text(result.documentName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: handleQuickLook) {
                Image(systemName: "eye")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            Button(action: handleSave) {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            Button(action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .contentShape(.rect)
        .onTapGesture { handleQuickLook() }
#if os(iOS)
        .fileMover(isPresented: Binding(get: { iosFiles != nil }, set: { _ = $0 }), files: iosFiles ?? []) { result in
            do {
                let gottenResults = try result.get()
                for gottenResult in gottenResults {
                    print(gottenResult.absoluteString)
                }
            } catch {
                print(error.localizedDescription)
            }
            iosFiles = nil
        }
#endif
    }
    
    private func handleQuickLook() {
        guard quickLookItem == nil else { return }
        let tempURL = URL.temporaryDirectory.appendingPathComponent("temp_\(Date().timeIntervalSince1970)", conformingTo: .png)
        do {
            try result.data.write(to: tempURL)
            quickLookItem = tempURL
        } catch {
            errorMsg = error.localizedDescription
        }
    }
#if os(iOS)
    @State var iosFiles: [URL]?
    @AppStorage("saveToPhotos") var saveToPhotos = true
#endif
    private func handleSave() {
#if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select a Folder to Save the Image to"
        if panel.runModal() == .OK, let url = panel.url {
            let name = result.name
            let docName = result.documentName.replacingOccurrences(of: ".png", with: "")
            let fileName = "\(docName) - \(name)"
            let saveURL = url.appendingPathComponent(fileName, conformingTo: .png)
            do {
                try result.data.write(to: saveURL)
            } catch {
                errorMsg = error.localizedDescription
            }
        }
#elseif os(iOS)
        var iosFileResults: [URL] = []
        let freshTempDir = URL.temporaryDirectory.appendingPathComponent("temp_\(Date().timeIntervalSince1970)", conformingTo: .folder)
        try? FileManager.default.createDirectory(at: freshTempDir, withIntermediateDirectories: true)
        if saveToPhotos {
            if let img = UIImage(data: result.data) {
                ImageSaver().writeToAlbum(image: img)
            }
        } else {
            let name = result.name
            let docName = result.documentName.replacingOccurrences(of: ".png", with: "")
            let fileName = "\(docName) - \(name)"
            let saveURL = freshTempDir.appendingPathComponent(fileName, conformingTo: .png)
            do {
                try result.data.write(to: saveURL)
                iosFileResults.append(saveURL)
            } catch {
                if errorMsg == nil {
                    errorMsg = error.localizedDescription
                } else {
                    errorMsg = "\(errorMsg ?? "")\n\(error.localizedDescription)"
                }
            }
            iosFiles = iosFileResults
        }
#endif
    }
}

struct PDFImageResult: Identifiable, Hashable {
    let id = UUID()
    var data: Data
    var name: String
    var documentName: String
}

import QuickLook

struct PDFPageSelectionView: View {
    let pdfDocument: PDFDocument
    let documentTitle: String
    let onDone: ([PDFImageResult]) -> Void
    
    @State private var selectedPages: Set<Int> = []
    @State var doneDisabled = false
    init(pdfURL: URL, onDone: @escaping ([PDFImageResult]) -> Void) {
        self.documentTitle = pdfURL.deletingPathExtension().lastPathComponent
        self.pdfDocument = PDFDocument(url: pdfURL) ?? PDFDocument()
        self.onDone = onDone
    }
    
    init(pdfData: Data, title: String? = nil, onDone: @escaping ([PDFImageResult]) -> Void) {
        self.documentTitle = title ?? "Untitled Document"
        self.pdfDocument = PDFDocument(data: pdfData) ?? PDFDocument()
        self.onDone = onDone
    }
    @AppStorage("listMode") var listMode = true
    @State var quickLookItem: URL?
    var body: some View {
        NavigationStack {
            VStack {
                if listMode {
                    List {
                        ForEach(0..<pdfDocument.pageCount, id: \.self) { index in
                            if let page = pdfDocument.page(at: index) {
                                PDFPageRow(
                                    page: page,
                                    index: index,
                                    isSelected: selectedPages.contains(index), listMode: true
                                ) {
                                    toggleSelection(for: index)
                                }
                                .contextMenu {
                                    Button(action: {
                                        let temp = URL.temporaryDirectory.appendingPathComponent("temp_\(Date().timeIntervalSince1970)", conformingTo: .pdf)
                                        let newDoc = PDFDocument()
                                        newDoc.insert(page, at: 0)
                                        if newDoc.write(to: temp) { quickLookItem = temp }
                                    }) {
                                        Label("Preview Page", systemImage: "eye")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
#if os(macOS)
                    .alternatingRowBackgrounds()
                    .frame(width: 450, height: 250)
#endif
                    
                } else {
                    ScrollView {
                        var columns: [GridItem] {
#if os(macOS)
                            Array(repeating: GridItem(.fixed(100)), count: 4)
#elseif os(iOS)
                            Array(repeating: GridItem(.fixed(100)), count: 3)
#endif
                        }
                        LazyVGrid(columns: columns) {
                            ForEach(0..<pdfDocument.pageCount, id: \.self) { index in
                                if let page = pdfDocument.page(at: index) {
                                    PDFPageRow(
                                        page: page,
                                        index: index,
                                        isSelected: selectedPages.contains(index), listMode: false
                                    ) {
                                        toggleSelection(for: index)
                                    }
                                    .contextMenu {
                                        Button(action: {
                                            let temp = URL.temporaryDirectory.appendingPathComponent("temp_\(Date().timeIntervalSince1970)", conformingTo: .pdf)
                                            let newDoc = PDFDocument()
                                            newDoc.insert(page, at: 0)
                                            if newDoc.write(to: temp) { quickLookItem = temp }
                                        }) {
                                            Label("Preview Page", systemImage: "eye")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .scrollIndicators(.never)
                    .padding()
#if os(macOS)
                    .frame(width: 450, height: 250)
#endif
                }
#if os(macOS)
                Text("Right Click to Preview Page")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #elseif os(iOS)
                Text("Long Press to Preview Page")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
                HStack {
                    Button(action: { withAnimation() { listMode.toggle() } }) {
                        Image(systemName: listMode ? "square.grid.2x2" : "list.bullet")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    Button(action: { selectedPages = Set(0..<pdfDocument.pageCount) }) { Text("Select All") }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    Button(action: { selectedPages.removeAll() }) { Text("Deselect All") }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    Spacer()
                    Button(action: {
                        if !doneDisabled {
                            doneDisabled = true
                            let results = exportSelectedPages()
                            onDone(results)
                        }
                    }) {
                        Text("Done")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(doneDisabled)
                }
                .padding(10)
            }
            .quickLookPreview($quickLookItem)
        }
    }
    
    private func toggleSelection(for index: Int) {
        if selectedPages.contains(index) {
            selectedPages.remove(index)
        } else {
            selectedPages.insert(index)
        }
    }
    
    private func exportSelectedPages() -> [PDFImageResult] {
        var results: [PDFImageResult] = []
        
        for index in selectedPages.sorted() {
            guard let page = pdfDocument.page(at: index) else { continue }
            
            let pageRect = page.bounds(for: .mediaBox)
#if os(macOS)
            let image = NSImage(size: pageRect.size)
            image.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.saveGState()
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.fill(CGRect(origin: .zero, size: pageRect.size))
                page.draw(with: .mediaBox, to: ctx)
                ctx.restoreGState()
            }
            image.unlockFocus()
            if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let pngData = rep.representation(using: .png, properties: [:]) {
                results.append(.init(data: pngData, name: "Page \(index + 1).png", documentName: documentTitle))
            }
#elseif os(iOS)
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = UIScreen.main.scale
            let renderer = UIGraphicsImageRenderer(size: pageRect.size, format: format)
            let uiImage = renderer.image { ctx in
                let cg = ctx.cgContext
                cg.saveGState()
                cg.setFillColor(UIColor.white.cgColor)
                cg.fill(CGRect(origin: .zero, size: pageRect.size))
                page.draw(with: .mediaBox, to: cg)
                cg.restoreGState()
            }
            if let pngData = uiImage.pngData() {
                results.append(.init(data: pngData, name: "Page \(index + 1).png", documentName: documentTitle))
            }
#endif
            
        }
        
        return results
    }
}

/// High-quality rendered preview
#if os(macOS)
private func renderPageImage(_ page: PDFPage, targetWidth: CGFloat = 300, thumbnail: Bool = false) -> NSImage {
    if thumbnail {
        return page.thumbnail(of: .init(width: targetWidth, height: targetWidth * sqrt(2)), for: .mediaBox)
    } else {
        let pageRect = page.bounds(for: .mediaBox)
        let scale = targetWidth / pageRect.width
        let scaledSize = NSSize(width: pageRect.width * scale, height: pageRect.height * scale)
        
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: scaledSize))
            ctx.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx)
            ctx.restoreGState()
        }
        image.unlockFocus()
        return image
    }
}
#elseif os(iOS)
private func renderPageImage(_ page: PDFPage, targetWidth: CGFloat = 300, thumbnail: Bool = false) -> UIImage {
    if thumbnail {
        return page.thumbnail(of: .init(width: targetWidth, height: targetWidth * sqrt(2)), for: .mediaBox)
    } else {
        let pageRect = page.bounds(for: .mediaBox)
        let scale = targetWidth / pageRect.width
        let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.saveGState()
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(CGRect(origin: .zero, size: scaledSize))
            cg.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: cg)
            cg.restoreGState()
        }
        return image
    }
}
#endif

#if os(macOS)
extension Image {
    init(pdfPage: PDFPage, thumbnail: Bool = false) {
        self = Image(nsImage: renderPageImage(pdfPage, thumbnail: thumbnail))
    }
}
#elseif os(iOS)
extension Image {
    init(pdfPage: PDFPage, thumbnail: Bool = false) {
        self = Image(uiImage: renderPageImage(pdfPage, thumbnail: thumbnail))
    }
}
#endif

private struct PDFPageRow: View {
    let page: PDFPage
    let index: Int
    let isSelected: Bool
    let listMode: Bool
    let onToggle: () -> Void
    var body: some View {
        if listMode {
            HStack {
                A4ImageView(Image(pdfPage: page, thumbnail: true), size: CGSize(width: 35.5, height: 50), cornerRadius: 5)
                VStack(alignment: .leading) {
                    Text("Page \(index + 1)")
                        .bold()
                    Text(page.label ?? "No Label")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .gray)
            }
            .contentShape(.rect)
            .onTapGesture {
                onToggle()
            }
        } else {
            VStack {
                A4ImageView(Image(pdfPage: page, thumbnail: true), size: {
#if os(macOS)
                    CGSize(width: 88.5, height: 125)
#elseif os(iOS)
                    CGSize(width: 100, height: 141.5)
#endif
                }, cornerRadius: 12)
                    .overlay(alignment: .top) {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(isSelected ? .accentColor : .gray)
#if os(iOS)
                                    .background(Color(uiColor: .systemBackground))
#elseif os(macOS)
                                    .background(.background)
#endif
                                    .clipShape(.circle)
                                    .padding(10)
                                    .animation(.default, value: isSelected)
                            }
                            Spacer()
                            HStack {
                                Spacer()
                                VStack {
                                    Text("Page \(index + 1)")
                                        .bold()
                                    Text(page.label ?? "No Label")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .foregroundStyle(.ultraThinMaterial)
                            )
                            .padding(2.5)
                        }
                    }
                    .onTapGesture {
                        onToggle()
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
        }
    }
}

struct A4ImageView: View {
    init(_ image: Image, size: CGSize, cornerRadius: CGFloat) {
        self.image = image
        self.size = {
            CustomSize(width: size.width, height: size.height)
        }()
        self.cornerRadius = cornerRadius
    }
    init(_ image: Image, size: () -> CGSize, cornerRadius: CGFloat) {
        self.image = image
        self.size = {
            CustomSize(width: size().width, height: size().height)
        }()
        self.cornerRadius = cornerRadius
    }
    init(_ image: Image, size: () -> CustomSize, cornerRadius: CGFloat) {
        self.image = image
        self.size = size()
        self.cornerRadius = cornerRadius
    }
    init(_ image: Image, size: CustomSize, cornerRadius: CGFloat) {
        self.image = image
        self.size = size
        self.cornerRadius = cornerRadius
    }
    var image: Image
    var size: CustomSize
    var cornerRadius: CGFloat
    var body: some View {
        Rectangle()
            .foregroundStyle(.background)
            .frame(width: size.width, height: size.height)
            .overlay {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.secondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct CustomSize {
    var width: CGFloat?
    var height: CGFloat?
}
