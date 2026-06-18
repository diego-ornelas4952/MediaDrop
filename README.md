# ⬇️ MediaDrop for macOS

![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)
![Interface](https://img.shields.io/badge/Interface-SwiftUI-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

MediaDownloader is a native macOS application built with Swift and SwiftUI. It acts as a lightweight and modern graphical user interface for the`yt-dlp` command-line tool, allowing users to download high-quality video and audio without needing to interact directly with the terminal.

---

## ✨ Key Features

* **Native Design:** Clean interface built in SwiftUI, leveraging native macOS components and visual effects.
* **Tailored Formats:** Easily choose between downloading the best available video quality or extracting only the audio (MP3).
* **Real-Time Progress:** Visual tracking of your file downloads and conversions.
* **Optimal Performance:** Background process execution to keep the user interface smooth and responsive at all times.

---

## 🛠️ Prerequisites

To build and run this project, your development environment must have:

* **macOS 11.0** (Big Sur) or later.
* **Xcode 13** or later.
* Static binaries for command-line dependencies:
  * `yt-dlp`
  * `ffmpeg` (Required for merging high-resolution video and audio tracks).

> **Note:** In future releases, these binaries are planned to be bundled directly within the *App Bundle* to eliminate the need for third-party installations.

---

## 🚀 Installation & Usage (Development)

1. **Clone this repository** to your local machine:
```bash
   git clone [https://github.com/your-username/MediaDrop.git](https://github.com/your-username/MediaDownloader.git)
```
2. **Open the project in Xcode**:
```bash
   cd MediaDrop
   open YTDLPMac.xcodeproj
```
3. **Configure settings**:
In the project settings (Targets > Signing & Capabilities), make sure to select your development team or set up local signing for testing.
