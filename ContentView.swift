import SwiftUI
import UniformTypeIdentifiers

struct BlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

enum AppMode: String, CaseIterable {
    case download = "Descargar"
    case convert = "Convertir"
}

struct ContentView: View {
    @StateObject private var downloadViewModel = DownloadViewModel()
    @StateObject private var convertViewModel = ConvertViewModel()
    
    @State private var appMode: AppMode = .download
    @State private var showLogs: Bool = false
    @State private var isDropTargeted: Bool = false
    
    var body: some View {
        ZStack {
            // Fondo con efecto dinámico dependiendo del modo
            LinearGradient(
                colors: appMode == .download ? [Color.blue.opacity(0.3), Color.purple.opacity(0.4)] : [Color.orange.opacity(0.3), Color.pink.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: appMode)
            
            // Círculos desenfocados para dar el efecto de Liquid Glass
            Circle()
                .fill(appMode == .download ? Color.pink.opacity(0.3) : Color.yellow.opacity(0.3))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -150, y: -150)
                .animation(.easeInOut(duration: 0.5), value: appMode)
                
            Circle()
                .fill(appMode == .download ? Color(red: 0, green: 1, blue: 1).opacity(0.3) : Color.purple.opacity(0.3))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: 150, y: 150)
                .animation(.easeInOut(duration: 0.5), value: appMode)
            
            // Tarjeta Principal (Liquid Glass)
            VStack(spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: appMode == .download ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(appMode == .download ? .blue : .orange)
                        .shadow(color: (appMode == .download ? Color.blue : Color.orange).opacity(0.5), radius: 10, x: 0, y: 5)
                        
                    Text(appMode == .download ? "MediaDrop Downloader" : "MediaDrop Converter")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.top, 10)
                
                // Selector de Modo
                Picker("", selection: $appMode) {
                    ForEach(AppMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                
                // Vistas dinámicas
                if appMode == .download {
                    downloadView()
                        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                } else {
                    convertView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                }
                
                // Toggle para mostrar/ocultar consola
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showLogs.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: showLogs ? "chevron.up" : "chevron.down")
                        Text(showLogs ? "Ocultar Registros" : "Ver Registros")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                // Consola de Estado
                if showLogs {
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                Text(appMode == .download ? downloadViewModel.terminalOutput : convertViewModel.terminalOutput)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(Color.primary.opacity(0.8))
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(12)
                                    .id("TerminalOutput")
                            }
                            .frame(height: 160)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .onChange(of: appMode == .download ? downloadViewModel.terminalOutput : convertViewModel.terminalOutput) { _ in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo("TerminalOutput", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(32)
            .background(BlurView())
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 25, x: 0, y: 12)
            .padding(40)
        }
        .frame(minWidth: 650, minHeight: showLogs ? 800 : 600)
        .animation(.spring(response: 0.4, dampingFraction: 0.8))
        .alert(isPresented: $downloadViewModel.showPlaylistAlert) {
            Alert(
                title: Text("¿Descargar Lista de Reproducción?"),
                message: Text("Hemos detectado que este enlace pertenece a una lista de reproducción. ¿Deseas descargar toda la lista en una carpeta nueva o solo el video individual?"),
                primaryButton: .default(Text("Toda la Lista"), action: {
                    withAnimation { downloadViewModel.confirmDownload(isPlaylist: true) }
                }),
                secondaryButton: .default(Text("Solo el Video"), action: {
                    withAnimation { downloadViewModel.confirmDownload(isPlaylist: false) }
                })
            )
        }
    }
    
    // MARK: - Download View
    @ViewBuilder
    private func downloadView() -> some View {
        VStack(spacing: 20) {
            // Barra de URL
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                TextField("Pega el enlace de YouTube aquí...", text: $downloadViewModel.urlString)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .disabled(downloadViewModel.isDownloading)
                
                if !downloadViewModel.urlString.isEmpty {
                    Button(action: {
                        withAnimation { downloadViewModel.urlString = "" }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(downloadViewModel.isDownloading)
                }
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor).opacity(0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            
            // Selector de Destino
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                Text(downloadViewModel.downloadsURL.path)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button(action: selectDownloadDestinationFolder) {
                    Text("Cambiar...")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .disabled(downloadViewModel.isDownloading)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
            .cornerRadius(12)
            
            // Ajustes de Calidad y Formato
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tipo")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Picker("", selection: $downloadViewModel.mediaType) {
                        ForEach(MediaType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(downloadViewModel.isDownloading)
                }
                
                Divider().frame(height: 40)
                
                if downloadViewModel.mediaType == .video {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Resolución")
                            .font(.caption).fontWeight(.semibold).foregroundColor(.secondary).textCase(.uppercase)
                        Picker("", selection: $downloadViewModel.videoQuality) {
                            ForEach(VideoQuality.allCases, id: \.self) { q in Text(q.rawValue).tag(q) }
                        }
                        .pickerStyle(.menu).labelsHidden().disabled(downloadViewModel.isDownloading)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Formato")
                            .font(.caption).fontWeight(.semibold).foregroundColor(.secondary).textCase(.uppercase)
                        Picker("", selection: $downloadViewModel.videoFormat) {
                            ForEach(VideoFormat.allCases, id: \.self) { f in Text(f.rawValue).tag(f) }
                        }
                        .pickerStyle(.menu).labelsHidden().disabled(downloadViewModel.isDownloading)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Calidad de Audio")
                            .font(.caption).fontWeight(.semibold).foregroundColor(.secondary).textCase(.uppercase)
                        Picker("", selection: $downloadViewModel.audioQuality) {
                            ForEach(AudioQuality.allCases, id: \.self) { q in Text(q.rawValue).tag(q) }
                        }
                        .pickerStyle(.menu).labelsHidden().disabled(downloadViewModel.isDownloading)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Formato")
                            .font(.caption).fontWeight(.semibold).foregroundColor(.secondary).textCase(.uppercase)
                        Picker("", selection: $downloadViewModel.audioFormat) {
                            ForEach(AudioFormat.allCases, id: \.self) { f in Text(f.rawValue).tag(f) }
                        }
                        .pickerStyle(.menu).labelsHidden().disabled(downloadViewModel.isDownloading)
                    }
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
            .cornerRadius(12)
            
            // Botón Principal y Barra de Progreso
            VStack(spacing: 12) {
                if downloadViewModel.isDownloading {
                    ProgressView(value: downloadViewModel.progress)
                        .progressViewStyle(.linear)
                        .accentColor(.blue)
                        .animation(.linear)
                }
                
                Button(action: {
                    withAnimation { downloadViewModel.startDownload() }
                }) {
                    HStack {
                        if downloadViewModel.isDownloading {
                            Image(systemName: "arrow.down.app")
                        } else if downloadViewModel.isCompleted {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 16, weight: .bold))
                        } else {
                            Image(systemName: "icloud.and.arrow.down").font(.system(size: 16, weight: .bold))
                        }
                        
                        if downloadViewModel.isDownloading {
                            Text("Descargando... \(Int(downloadViewModel.progress * 100))%")
                        } else if downloadViewModel.isCompleted {
                            Text("Completado")
                        } else {
                            Text("Iniciar Descarga")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: downloadViewModel.isDownloading ? [.gray, .gray.opacity(0.8)] : 
                                    downloadViewModel.isCompleted ? [.green, Color(red: 0, green: 0.8, blue: 0.6)] : [.blue, Color(red: 0.3, green: 0, blue: 0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: downloadViewModel.isDownloading ? .clear : 
                            downloadViewModel.isCompleted ? .green.opacity(0.4) : .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(downloadViewModel.urlString.isEmpty || downloadViewModel.isDownloading)
            }
        }
        .onChange(of: downloadViewModel.urlString) { _ in
            withAnimation { downloadViewModel.isCompleted = false }
        }
    }
    
    // MARK: - Convert View
    @ViewBuilder
    private func convertView() -> some View {
        VStack(spacing: 20) {
            // Seleccionar Archivo
            HStack {
                Image(systemName: "doc")
                    .foregroundColor(.secondary)
                Text(convertViewModel.inputFileURL?.lastPathComponent ?? "Selecciona o arrastra un archivo local...")
                    .font(.system(size: 14))
                    .foregroundColor(convertViewModel.inputFileURL == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                if convertViewModel.inputFileURL != nil {
                    Button(action: {
                        withAnimation { convertViewModel.inputFileURL = nil }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(convertViewModel.isConverting)
                }
                
                Button(action: selectFileToConvert) {
                    Text("Buscar")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .disabled(convertViewModel.isConverting)
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor).opacity(isDropTargeted ? 0.3 : 0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDropTargeted ? Color.orange : Color.white.opacity(0.2), lineWidth: isDropTargeted ? 2 : 1)
            )
            .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
                if let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            let validExts = ["mp3", "mp4", "mkv", "webm", "wav", "m4a", "aac", "flac", "ogg", "mov", "avi", "m4v", "mpg", "mpeg"]
                            if validExts.contains(url.pathExtension.lowercased()) {
                                DispatchQueue.main.async {
                                    convertViewModel.inputFileURL = url
                                }
                            }
                        }
                    }
                    return true
                }
                return false
            }
            
            // Selector de Destino
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                Text(convertViewModel.destinationURL.path)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button(action: selectConversionDestinationFolder) {
                    Text("Cambiar...")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .disabled(convertViewModel.isConverting)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
            .cornerRadius(12)
            
            // Ajustes de Formato
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Convertir A")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.secondary).textCase(.uppercase)
                    Picker("", selection: $convertViewModel.outputType) {
                        ForEach(MediaType.allCases, id: \.self) { type in Text(type.rawValue).tag(type) }
                    }
                    .pickerStyle(.segmented).labelsHidden().disabled(convertViewModel.isConverting)
                }
                
                Divider().frame(height: 40)
                
                if convertViewModel.outputType == .video {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Formato")
                            .font(.caption).fontWeight(.semibold).foregroundColor(.secondary).textCase(.uppercase)
                        Picker("", selection: $convertViewModel.videoFormat) {
                            ForEach(VideoFormat.allCases, id: \.self) { f in Text(f.rawValue).tag(f) }
                        }
                        .pickerStyle(.menu).labelsHidden().disabled(convertViewModel.isConverting)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Formato")
                            .font(.caption).fontWeight(.semibold).foregroundColor(.secondary).textCase(.uppercase)
                        Picker("", selection: $convertViewModel.audioFormat) {
                            ForEach(AudioFormat.allCases, id: \.self) { f in Text(f.rawValue).tag(f) }
                        }
                        .pickerStyle(.menu).labelsHidden().disabled(convertViewModel.isConverting)
                    }
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
            .cornerRadius(12)
            
            // Botón Principal de Conversión
            VStack(spacing: 12) {
                if convertViewModel.isConverting {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .accentColor(.orange)
                }
                
                Button(action: {
                    withAnimation { convertViewModel.startConversion() }
                }) {
                    HStack {
                        if convertViewModel.isConverting {
                            Image(systemName: "hourglass")
                        } else if convertViewModel.isCompleted {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 16, weight: .bold))
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 16, weight: .bold))
                        }
                        
                        if convertViewModel.isConverting {
                            Text("Convirtiendo...")
                        } else if convertViewModel.isCompleted {
                            Text("Completado")
                        } else {
                            Text("Iniciar Conversión")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: convertViewModel.isConverting ? [.gray, .gray.opacity(0.8)] : 
                                    convertViewModel.isCompleted ? [.green, Color(red: 0, green: 0.8, blue: 0.6)] : [.orange, .pink],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: convertViewModel.isConverting ? .clear : 
                            convertViewModel.isCompleted ? .green.opacity(0.4) : .orange.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(convertViewModel.inputFileURL == nil || convertViewModel.isConverting)
            }
        }
        .onChange(of: convertViewModel.inputFileURL) { _ in
            withAnimation { convertViewModel.isCompleted = false }
        }
    }
    
    // MARK: - Helpers Panel
    private func selectDownloadDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Seleccionar Carpeta"
        if panel.runModal() == .OK, let url = panel.url {
            downloadViewModel.downloadsURL = url
        }
    }
    
    private func selectConversionDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Seleccionar Carpeta"
        if panel.runModal() == .OK, let url = panel.url {
            convertViewModel.destinationURL = url
        }
    }
    
    private func selectFileToConvert() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.prompt = "Seleccionar Archivo"
        if panel.runModal() == .OK, let url = panel.url {
            convertViewModel.inputFileURL = url
        }
    }
}

#Preview {
    ContentView()
}
