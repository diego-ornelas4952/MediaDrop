import Foundation
import Combine
import UserNotifications

class ConvertViewModel: ObservableObject {
    @Published var inputFileURL: URL? = nil
    @Published var isConverting: Bool = false
    @Published var isCompleted: Bool = false
    @Published var terminalOutput: String = ""
    
    @Published var outputType: MediaType = .audio
    @Published var videoFormat: VideoFormat = .mp4
    @Published var audioFormat: AudioFormat = .mp3
    
    @Published var destinationURL: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    
    private var process: Process?
    
    func startConversion() {
        guard let inputURL = inputFileURL else { return }
        
        isConverting = true
        isCompleted = false
        terminalOutput = "Iniciando conversión de \(inputURL.lastPathComponent)...\n"
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.executeConversion(inputURL: inputURL)
        }
    }
    
    private func sendNotification(fileName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Conversión Completada"
        content.body = "Tu archivo \(fileName) se ha convertido exitosamente."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func executeConversion(inputURL: URL) {
        let process = Process()
        self.process = process
        
        guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else {
            DispatchQueue.main.async { [weak self] in
                self?.terminalOutput += "\n❌ Error: No se encontró 'ffmpeg' en el Bundle. Asegúrate de haberlo arrastrado al proyecto."
                self?.isConverting = false
            }
            return
        }
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        
        let originalName = inputURL.deletingPathExtension().lastPathComponent
        let ext = outputType == .video ? videoFormat.rawValue.lowercased() : audioFormat.rawValue.lowercased()
        let outputFileName = "\(originalName)_convertido.\(ext)"
        let outputURL = destinationURL.appendingPathComponent(outputFileName)
        
        // ffmpeg -y -i input ... output
        var args = ["-y", "-i", inputURL.path]
        
        if outputType == .audio {
            args.append("-vn") // no video
            if ext == "mp3" {
                args.append(contentsOf: ["-c:a", "libmp3lame", "-q:a", "2"])
            } else if ext == "wav" {
                args.append(contentsOf: ["-c:a", "pcm_s16le"])
            } else {
                args.append(contentsOf: ["-c:a", "aac", "-b:a", "256k"]) // m4a
            }
        } else {
            // Conversión de video genérica de alta compatibilidad
            args.append(contentsOf: ["-c:v", "libx264", "-c:a", "aac"])
        }
        
        args.append(outputURL.path)
        process.arguments = args
        
        let pipe = Pipe()
        process.standardError = pipe // ffmpeg manda el output del progreso a stderr
        
        let fileHandle = pipe.fileHandleForReading
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.count > 0 {
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.terminalOutput += output
                    }
                }
            }
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            DispatchQueue.main.async { [weak self] in
                self?.isConverting = false
                if process.terminationStatus == 0 {
                    self?.isCompleted = true
                    self?.terminalOutput += "\n✅ Conversión Finalizada: \(outputFileName)"
                    self?.sendNotification(fileName: outputFileName)
                } else {
                    self?.terminalOutput += "\n⚠️ La conversión falló con código \(process.terminationStatus)."
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.terminalOutput += "\n❌ Error al ejecutar ffmpeg: \(error.localizedDescription)"
                self?.isConverting = false
            }
        }
        
        fileHandle.readabilityHandler = nil
    }
}
