import SwiftUI
import Darwin

@main
struct DetectorTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 560, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 560, height: 640)
    }
}

// MARK: - Detection Engine

@MainActor
final class ScreenRecordingDetector: ObservableObject {

    @Published var isBeingRecorded = false
    @Published var detectedApps: [DetectedApp] = []
    @Published var lastCheckTime: Date = Date()
    @Published var checkCount: Int = 0
    @Published var detectionLog: [LogEntry] = []

    private var timer: Timer?

    struct DetectedApp: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let bundleID: String
        let pid: Int
        let method: String
    }

    struct LogEntry: Identifiable {
        let id = UUID()
        let time: Date
        let message: String
        let isAlert: Bool
    }

    // ================================================================
    // MARK: Method 1 — Video File Write Detection (strongest signal)
    // ================================================================
    // Use proc_pidfdinfo to check each running process's open file
    // descriptors. If a process has an open WRITE handle on a video
    // file (.mp4, .mov, .mkv, .avi, .ts, .webm), it's very likely
    // actively recording.

    private func detectViaVideoFileWrite() -> [DetectedApp] {
        var results: [DetectedApp] = []
        let myPID = ProcessInfo.processInfo.processIdentifier

        let allPIDs = getAllPIDs()
        let videoExtensions = [".mp4", ".mov", ".mkv", ".avi", ".ts", ".webm", ".m4v"]
        let recordingPathKeywords = ["screen recording", "screenrecording", "录屏",
                                      "screen capture", "screencapture"]

        for pid in allPIDs {
            if pid <= 0 || pid == myPID { continue }

            // Get list of FDs
            let bufSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
            guard bufSize > 0 else { continue }

            let fdInfoSize = MemoryLayout<proc_fdinfo>.stride
            let fdCount = Int(bufSize) / fdInfoSize
            guard fdCount > 0 else { continue }

            var fdBuffer = [proc_fdinfo](repeating: proc_fdinfo(), count: fdCount)
            let actualSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fdBuffer, bufSize)
            guard actualSize > 0 else { continue }

            let actualCount = Int(actualSize) / fdInfoSize
            var foundVideo = false
            var videoPath = ""

            for i in 0..<actualCount {
                let fd = fdBuffer[i]
                // Only check vnode (file) descriptors
                guard fd.proc_fdtype == PROX_FDTYPE_VNODE else { continue }

                var vnodeInfo = vnode_fdinfowithpath()
                let vnSize = MemoryLayout<vnode_fdinfowithpath>.stride
                let ret = proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDVNODEPATHINFO,
                                         &vnodeInfo, Int32(vnSize))
                guard ret > 0 else { continue }

                let path = withUnsafePointer(to: &vnodeInfo.pvip.vip_path) { ptr in
                    ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { cPtr in
                        String(cString: cPtr)
                    }
                }

                guard !path.isEmpty else { continue }
                let lowerPath = path.lowercased()

                // Check 1: file has a video extension
                let hasVideoExt = videoExtensions.contains { lowerPath.hasSuffix($0) }

                // Check 2: path contains recording-related keywords
                let hasRecordingKeyword = recordingPathKeywords.contains { lowerPath.contains($0) }

                if hasVideoExt || hasRecordingKeyword {
                    // Verify it's open for writing (the openFlags field)
                    // FWRITE = 0x0002 on macOS
                    let isWriting = (vnodeInfo.pfi.fi_openflags & 0x0002) != 0
                    if isWriting {
                        foundVideo = true
                        videoPath = path
                        break
                    }
                }
            }

            if foundVideo {
                let name = getProcessAppName(pid) ?? getProcessName(pid)
                let bundleID = getProcessBundleID(pid)
                // Extract just the filename for the log
                let fileName = (videoPath as NSString).lastPathComponent
                results.append(DetectedApp(
                    name: name, bundleID: bundleID,
                    pid: Int(pid), method: "Writing: \(fileName)"))
            }
        }
        return results
    }

    // ================================================================
    // MARK: Method 2 — System Helper Process Detection
    // ================================================================
    // When macOS's built-in screen recording (Cmd+Shift+5) is active,
    // the system spawns `screencaptureui`. Detect that.

    private func detectViaSystemHelpers() -> [DetectedApp] {
        var results: [DetectedApp] = []
        let myPID = Int(ProcessInfo.processInfo.processIdentifier)
        let helperNames: Set<String> = ["screencaptureui", "screencapture"]

        let allPIDs = getAllPIDs()
        for pid in allPIDs {
            if pid <= 0 || Int(pid) == myPID { continue }
            let name = getProcessName(pid)
            if name.isEmpty { continue }
            if helperNames.contains(name.lowercased()) {
                results.append(DetectedApp(
                    name: name, bundleID: "",
                    pid: Int(pid), method: "System Helper"))
            }
        }
        return results
    }

    // ================================================================
    // MARK: Helpers
    // ================================================================

    private func getAllPIDs() -> [pid_t] {
        let bufSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufSize > 0 else { return [] }
        let count = Int(bufSize) / MemoryLayout<pid_t>.stride
        var pids = [pid_t](repeating: 0, count: count + 16)
        let actual = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids,
                                    Int32(pids.count * MemoryLayout<pid_t>.stride))
        let actualCount = Int(actual) / MemoryLayout<pid_t>.stride
        return Array(pids.prefix(max(0, actualCount)))
    }

    private func getProcessName(_ pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 1024)
        let len = proc_name(pid, &buf, UInt32(buf.count))
        guard len > 0 else { return "" }
        return String(cString: buf)
    }

    private func getProcessAppName(_ pid: pid_t) -> String? {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return app.localizedName
    }

    private func getProcessBundleID(_ pid: pid_t) -> String {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return "" }
        return app.bundleIdentifier ?? ""
    }

    // ================================================================
    // MARK: Orchestration
    // ================================================================

    func startMonitoring() {
        addLog("Engine started: VideoFileWrite + SystemHelper", alert: false)
        performCheck()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performCheck()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func performCheck() {
        checkCount += 1
        lastCheckTime = Date()

        var allDetected: [Int: DetectedApp] = [:]

        // Method 1: Video file write detection (strongest, no false positives)
        for app in detectViaVideoFileWrite() {
            allDetected[app.pid] = app
        }

        // Method 2: System helper processes
        for app in detectViaSystemHelpers() {
            if allDetected[app.pid] == nil { allDetected[app.pid] = app }
        }

        let newList = Array(allDetected.values).sorted { $0.name < $1.name }
        let wasRecording = isBeingRecorded
        detectedApps = newList
        isBeingRecorded = !newList.isEmpty

        if isBeingRecorded && !wasRecording {
            let names = newList.map { "\($0.name)(\($0.method))" }.joined(separator: ", ")
            addLog("ALERT: \(names)", alert: true)
        } else if !isBeingRecorded && wasRecording {
            addLog("Cleared: no recording detected", alert: false)
        }
    }

    func addLog(_ message: String, alert: Bool) {
        let entry = LogEntry(time: Date(), message: message, isAlert: alert)
        detectionLog.insert(entry, at: 0)
        if detectionLog.count > 50 { detectionLog.removeLast() }
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var detector = ScreenRecordingDetector()
    @State private var pulseAnimation = false
    @State private var showLog = false

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                titleBar.padding(.top, 16)
                Spacer().frame(height: 28)
                statusCard.padding(.horizontal, 28)
                Spacer().frame(height: 20)
                detectionMethodBadges.padding(.horizontal, 28)
                Spacer().frame(height: 16)
                detectedAppsList.padding(.horizontal, 28)
                Spacer()
                if showLog { logPanel.padding(.horizontal, 28) }
                footer.padding(.bottom, 16)
            }
        }
        .onAppear { detector.startMonitoring() }
        .onDisappear { detector.stopMonitoring() }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: detector.isBeingRecorded
                ? [Color(hex: "1a0a0a"), Color(hex: "2d1117"), Color(hex: "1a0a0a")]
                : [Color(hex: "0a0f1a"), Color(hex: "0f1729"), Color(hex: "0a0f1a")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.easeInOut(duration: 1.0), value: detector.isBeingRecorded)
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            Image(systemName: "eye.trianglebadge.exclamationmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                )
            Text("Recording Detector")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Text("\(detector.checkCount) checks")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(
                    Capsule().fill(.white.opacity(0.06))
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 18) {
            ZStack {
                if detector.isBeingRecorded {
                    Circle().fill(Color.red.opacity(0.08))
                        .frame(width: 96, height: 96)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.6)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)
                    Circle().fill(Color.red.opacity(0.12))
                        .frame(width: 76, height: 76)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.8)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.3), value: pulseAnimation)
                }
                Circle()
                    .fill(
                        detector.isBeingRecorded
                            ? LinearGradient(colors: [Color(hex: "ff4444"), Color(hex: "cc2233")], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color(hex: "22c55e"), Color(hex: "16a34a")], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: detector.isBeingRecorded ? .red.opacity(0.4) : .green.opacity(0.3), radius: 20)
                    .overlay(
                        Image(systemName: detector.isBeingRecorded ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                            .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                    )
            }
            .onAppear { pulseAnimation = true }

            VStack(spacing: 5) {
                Text(detector.isBeingRecorded ? "Screen Recording Detected!" : "No Recording Detected")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(detector.isBeingRecorded ? Color(hex: "ff6b6b") : Color(hex: "4ade80"))
                Text(detector.isBeingRecorded
                     ? "Found \(detector.detectedApps.count) recording app\(detector.detectedApps.count > 1 ? "s" : "")"
                     : "Your screen appears to be private")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.3))
                .background(RoundedRectangle(cornerRadius: 20)
                    .fill(detector.isBeingRecorded ? Color.red.opacity(0.05) : Color.green.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(detector.isBeingRecorded ? Color.red.opacity(0.15) : Color.green.opacity(0.1), lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.5), value: detector.isBeingRecorded)
    }

    // MARK: - Detection Method Badges

    private var detectionMethodBadges: some View {
        HStack(spacing: 8) {
            methodBadge(icon: "doc.text.magnifyingglass", label: "Video File Write", color: .cyan)
            methodBadge(icon: "gearshape.2", label: "System Helpers", color: .orange)
        }
    }

    private func methodBadge(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(color.opacity(0.7))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            Capsule().fill(color.opacity(0.08))
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Detected Apps List

    private var detectedAppsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Detected Apps")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(detector.lastCheckTime, style: .time)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }

            if detector.detectedApps.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(detector.detectedApps) { app in
                            detectedAppRow(app)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private var emptyStateView: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.2))
            VStack(alignment: .leading, spacing: 2) {
                Text("All Clear")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                Text("No screen recording apps detected")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.25))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.03))
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func detectedAppRow(_ app: ScreenRecordingDetector.DetectedApp) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Color.red.opacity(0.3), Color.orange.opacity(0.2)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 34, height: 34)
                Image(systemName: "video.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                HStack(spacing: 6) {
                    if !app.bundleID.isEmpty {
                        Text(app.bundleID)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                            .lineLimit(1)
                    }
                    Text(app.method)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.7))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(.cyan.opacity(0.1)))
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("PID \(app.pid)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.red.opacity(0.7))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.red.opacity(0.1))
                        .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.04))
                .strokeBorder(Color.red.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Log Panel

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Detection Log")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(detector.detectionLog) { entry in
                        HStack(alignment: .top, spacing: 6) {
                            Text(entry.time, style: .time)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white.opacity(0.25))
                            Text(entry.message)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(entry.isAlert ? .red.opacity(0.8) : .white.opacity(0.4))
                                .lineLimit(2)
                        }
                    }
                }
            }
            .frame(maxHeight: 80)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.3))
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: { detector.performCheck() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .bold))
                        Text("Check Now").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(
                        Capsule().fill(.white.opacity(0.06))
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button(action: { withAnimation { showLog.toggle() } }) {
                    HStack(spacing: 5) {
                        Image(systemName: "list.bullet.rectangle").font(.system(size: 10, weight: .bold))
                        Text(showLog ? "Hide Log" : "Show Log").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(
                        Capsule().fill(.white.opacity(0.06))
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Text("Video File Write + System Helpers · Polling every 0.5s")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.2))
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
