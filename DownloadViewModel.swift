import Foundation
import Combine
import UserNotifications

enum MediaType: String, CaseIterable {
    case video = "Video"
    case audio = "Audio"
}

enum VideoFormat: String, CaseIterable {
    case mp4 = "MP4"
    case mkv = "MKV"
    case webm = "WebM"
}

enum VideoQuality: String, CaseIterable {
    case best = "Mejor Calidad"
    case p1080 = "1080p"
    case p720 = "720p"
    case p480 = "480p"
}

enum AudioFormat: String, CaseIterable {
    case mp3 = "MP3"
    case m4a = "M4A"
    case wav = "WAV"
}

enum AudioQuality: String, CaseIterable {
    case best = "Mejor (0)"
    case high = "Alta (320k)"
    case medium = "Media (192k)"
    case low = "Baja (128k)"
}

class DownloadViewModel: ObservableObject {
    @Published var urlString: String = ""
    @Published var isDownloading: Bool = false
    @Published var isCompleted: Bool = false
    @Published var showPlaylistAlert: Bool = false
    private var isPlaylistDownload: Bool = false
    @Published var terminalOutput: String = ""
    @Published var progress: Double = 0.0
    
    // Carpeta de destino (por defecto: Descargas)
    @Published var downloadsURL: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    
    // Opciones
    @Published var mediaType: MediaType = .video
    @Published var videoFormat: VideoFormat = .mp4
    @Published var videoQuality: VideoQuality = .best
    @Published var audioFormat: AudioFormat = .mp3
    @Published var audioQuality: AudioQuality = .best
    
    private var process: Process?
    
    init() {
        checkForUpdates()
    }
    
    private func checkForUpdates() {
        guard let ytDlpPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytDlpPath)
            process.arguments = ["-U"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            DispatchQueue.main.async {
                self?.terminalOutput += "Buscando actualizaciones de yt-dlp...\n"
            }
            
            let fileHandle = pipe.fileHandleForReading
            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.count > 0, let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.terminalOutput += output
                    }
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    self?.terminalOutput += "✅ Revisión de actualizaciones finalizada.\n\n"
                }
            } catch {
                DispatchQueue.main.async {
                    self?.terminalOutput += "❌ Error al actualizar yt-dlp: \(error.localizedDescription)\n\n"
                }
            }
            fileHandle.readabilityHandler = nil
        }
    }
    
    func startDownload() {
        guard !urlString.isEmpty else { return }
        
        if urlString.lowercased().contains("list=") || urlString.lowercased().contains("playlist") {
            showPlaylistAlert = true
        } else {
            confirmDownload(isPlaylist: false)
        }
    }
    
    func confirmDownload(isPlaylist: Bool) {
        self.isPlaylistDownload = isPlaylist
        
        isDownloading = true
        isCompleted = false
        progress = 0.0
        terminalOutput = "Iniciando descarga...\n"
        
        // Pedir permiso para notificaciones
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.executeDownload()
        }
    }
    
    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Descarga Completada"
        content.body = "Tu archivo de \(mediaType.rawValue) ha terminado de descargarse."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func executeDownload() {
        let process = Process()
        self.process = process
        
        guard let ytDlpPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) else {
            DispatchQueue.main.async { [weak self] in
                self?.terminalOutput += "\n❌ Error: No se encontró 'yt-dlp' en el Bundle."
                self?.isDownloading = false
            }
            return
        }
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        
        let outputTemplate: String
        var args = [String]()
        
        if isPlaylistDownload {
            // Usa el nombre de la playlist para crear una subcarpeta automáticamente
            outputTemplate = "\(downloadsURL.path)/%(playlist_title)s/%(title)s.%(ext)s"
            args.append("--yes-playlist")
        } else {
            outputTemplate = "\(downloadsURL.path)/%(title)s.%(ext)s"
            args.append("--no-playlist")
        }
        
        args.append(contentsOf: ["-o", outputTemplate])
        
        if let resourcesPath = Bundle.main.resourcePath {
            args.append(contentsOf: ["--ffmpeg-location", resourcesPath])
        }
        
        if mediaType == .video {
            args.append(contentsOf: ["--merge-output-format", videoFormat.rawValue.lowercased()])
            
            var qualityArg = "bestvideo+bestaudio/best"
            switch videoQuality {
            case .best: qualityArg = "bestvideo+bestaudio/best"
            case .p1080: qualityArg = "bestvideo[height<=1080]+bestaudio/best[height<=1080]"
            case .p720: qualityArg = "bestvideo[height<=720]+bestaudio/best[height<=720]"
            case .p480: qualityArg = "bestvideo[height<=480]+bestaudio/best[height<=480]"
            }
            args.append(contentsOf: ["-f", qualityArg])
        } else {
            args.append(contentsOf: ["-x", "--audio-format", audioFormat.rawValue.lowercased()])
            
            var aq = "0"
            switch audioQuality {
            case .best: aq = "0"
            case .high: aq = "320K"
            case .medium: aq = "192K"
            case .low: aq = "128K"
            }
            args.append(contentsOf: ["--audio-quality", aq])
        }
        
        args.append(self.urlString)
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        let fileHandle = pipe.fileHandleForReading
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.count > 0 {
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.terminalOutput += output
                        
                        // Expresión regular para parsear el porcentaje de descarga (ej. "25.4%")
                        if let matchRange = output.range(of: #"(\d+\.?\d*)%"#, options: .regularExpression) {
                            let percentageStr = String(output[matchRange].dropLast())
                            if let val = Double(percentageStr) {
                                self?.progress = val / 100.0
                            }
                        }
                    }
                }
            }
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            DispatchQueue.main.async { [weak self] in
                self?.isDownloading = false
                if process.terminationStatus == 0 {
                    self?.progress = 1.0 // Asegurar que marque 100% al terminar
                    self?.isCompleted = true
                    self?.terminalOutput += "\n✅ Proceso Finalizado."
                    self?.sendNotification()
                } else {
                    self?.terminalOutput += "\n⚠️ El proceso finalizó con errores o advertencias."
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.terminalOutput += "\n❌ Error al ejecutar el proceso: \(error.localizedDescription)"
                self?.isDownloading = false
            }
        }
        
        fileHandle.readabilityHandler = nil
    }
    
    func cancelDownload() {
        process?.terminate()
        isDownloading = false
        terminalOutput += "\n⚠️ Descarga cancelada por el usuario."
    }
}
