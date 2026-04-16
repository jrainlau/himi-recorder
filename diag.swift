#!/usr/bin/env swift

import Cocoa

print("=== Screen Info (no capture APIs) ===")
print("")

for (i, screen) in NSScreen.screens.enumerated() {
    print("Screen \(i): frame=\(screen.frame)")
    if screen == NSScreen.main {
        print("  ^ MAIN screen")
    }
}

print("")

let mainDisplayID = CGMainDisplayID()
print("Main display ID: \(mainDisplayID)")
print("CGDisplayBounds: \(CGDisplayBounds(mainDisplayID))")
print("CGDisplayPixelsWide: \(CGDisplayPixelsWide(mainDisplayID))")
print("CGDisplayPixelsHigh: \(CGDisplayPixelsHigh(mainDisplayID))")

let maxDisplays: UInt32 = 10
var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
var displayCount: UInt32 = 0
CGGetActiveDisplayList(maxDisplays, &displayIDs, &displayCount)

print("")
for i in 0..<Int(displayCount) {
    let did = displayIDs[i]
    print("Display \(did): bounds=\(CGDisplayBounds(did)), pixels=\(CGDisplayPixelsWide(did))x\(CGDisplayPixelsHigh(did))")
}

print("")
print("macOS version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
print("")
print("=== Done ===")
