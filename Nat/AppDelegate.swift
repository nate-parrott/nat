//
//  AppDelegate.swift
//  Nat
//
//  Created by nate parrott on 1/5/25.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize dictation
        _ = DictationManager.shared
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @IBAction func showSettings(_ sender: AnyObject?) {
        if let existing = NSApp.windows.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("Settings") }) {
            existing.makeKeyAndOrderFront(sender)
        } else {
            let windowController = NSStoryboard.main!.instantiateController(withIdentifier: "SettingsWindowController") as! NSWindowController
            windowController.window?.makeKeyAndOrderFront(sender)
        }
    }
}

