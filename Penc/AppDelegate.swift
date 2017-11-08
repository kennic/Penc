//
//  AppDelegate.swift
//  Penc
//
//  Created by Deniz Gurkaynak on 31.10.2017.
//  Copyright © 2017 Deniz Gurkaynak. All rights reserved.
//

import Cocoa
import Foundation
import ApplicationServices
import Silica
import MASShortcut


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, GestureOverlayWindowDelegate, ActivationHandlerDelegate, PreferencesDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let gestureOverlayWindow = GestureOverlayWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
    let placeholderWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 0, height: 0), styleMask: [NSWindow.StyleMask.borderless], backing: NSWindow.BackingStoreType.buffered, defer: true)
    let preferencesWindow = NSWindow(contentViewController: PreferencesViewController.freshController())
    let aboutWindow = NSWindow(contentViewController: AboutViewController.freshController())
    var focusedWindow: SIWindow? = nil
    var focusedScreen: NSScreen? = nil
    let activationHandler = ActivationHandler()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("penc-menu-icon"))
        }
        
        if checkPermissions() {
            constructMenu()
            Preferences.shared.setDelegate(self)
            self.gestureOverlayWindow.setDelegate(self)
            self.activationHandler.setDelegate(self)
            
            self.setupPlaceholderWindow()
            self.setupOverlayWindow()
            self.setupPreferencesWindow()
            self.setupAboutWindow()
            self.onPreferencesChanged(preferences: Preferences.shared)
        } else {
            let warnAlert = NSAlert();
            warnAlert.messageText = "Accessibility permissions needed";
            warnAlert.informativeText = "Penc relies upon having permission to 'control your computer'. If the permission prompt did not appear automatically, go to System Preferences, Security & Privacy, Accessibility, and add Penc to the list of allowed apps. Then relaunch Penc."
            warnAlert.layout()
            warnAlert.runModal()
            NSApplication.shared.terminate(self)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func checkPermissions() -> Bool {
        if AXIsProcessTrusted() {
            return true
        } else {
            let options = NSDictionary(object: kCFBooleanTrue, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
            
            let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
            return accessibilityEnabled
        }
    }
    
    func constructMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(AppDelegate.openPreferencesWindow(_:)), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About Penc", action: #selector(AppDelegate.openAboutWindow(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        self.statusItem.menu = menu
    }
    
    func setupPlaceholderWindow() {
        self.placeholderWindow.level = .floating
        self.placeholderWindow.isOpaque = false
        self.placeholderWindow.backgroundColor = NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.0, alpha: 0.25)
    }
    
    func setupOverlayWindow() {
        self.gestureOverlayWindow.level = .popUpMenu
        self.gestureOverlayWindow.isOpaque = false
        self.gestureOverlayWindow.ignoresMouseEvents = false
        self.gestureOverlayWindow.contentView!.allowedTouchTypes = [.indirect]
        self.gestureOverlayWindow.backgroundColor = NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    }
    
    func setupPreferencesWindow() {
        self.preferencesWindow.title = "Penc Preferences"
        self.preferencesWindow.styleMask.remove(.resizable)
        self.preferencesWindow.styleMask.remove(.miniaturizable)
    }
    
    @objc func openPreferencesWindow(_ sender: Any?) {
        self.preferencesWindow.makeKeyAndOrderFront(self.preferencesWindow)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func setupAboutWindow() {
        self.aboutWindow.titleVisibility = .hidden
        self.aboutWindow.styleMask.remove(.resizable)
        self.aboutWindow.styleMask.remove(.miniaturizable)
    }
    
    @objc func openAboutWindow(_ sender: Any?) {
        self.aboutWindow.makeKeyAndOrderFront(self.aboutWindow)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func onPreferencesChanged(preferences: Preferences) {
//        self.gestureHandler.moveModifierFlags = preferences.modifierKey1Mask
//        self.gestureHandler.resizeFactorModifierFlags = preferences.modifierKey1Mask
//        self.gestureHandler.swipeModifierFlags = preferences.modifierKey1Mask
//        self.gestureHandler.earlyBeginDelay = Double(preferences.activationDelay)
        self.gestureOverlayWindow.shouldInferMagnificationAngle = preferences.inferMagnificationAngle
    }
    
    func onActivated(activationHandler: ActivationHandler) {
        self.focusedWindow = SIWindow.focused()
        guard self.focusedWindow != nil else { return }
        self.focusedScreen = self.focusedWindow!.screen()
        guard self.focusedScreen != nil else { return }
        guard self.focusedWindow!.frame() != self.focusedScreen!.frame else { return } // fullscreen
        
        let focusedWindowRect = self.focusedWindow!.frame().topLeft2bottomLeft(self.focusedScreen!)
        self.placeholderWindow.setFrame(focusedWindowRect, display: true, animate: false)
        self.placeholderWindow.makeKeyAndOrderFront(self.placeholderWindow)
        
        let focusedScreenRect = self.focusedScreen!.frame.topLeft2bottomLeft(self.focusedScreen!)
        self.gestureOverlayWindow.setFrame(focusedScreenRect, display: true, animate: false)
        self.gestureOverlayWindow.makeKeyAndOrderFront(self.gestureOverlayWindow)
        
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func onDeactivated(activationHandler: ActivationHandler) {
        guard self.focusedWindow != nil else { return }
        guard self.focusedScreen != nil else { return }
        
        let newRect = self.placeholderWindow.frame.topLeft2bottomLeft(self.focusedScreen!)
        self.focusedWindow!.setFrame(newRect)
        self.focusedWindow!.focus()
        self.placeholderWindow.orderOut(self.placeholderWindow)
        self.gestureOverlayWindow.orderOut(self.gestureOverlayWindow)
        
        self.focusedWindow = nil
        self.focusedScreen = nil
    }
    
    func onMoveGesture(gestureOverlayWindow: GestureOverlayWindow, delta: (x: CGFloat, y: CGFloat)) {
        guard self.focusedWindow != nil else { return }
        guard self.focusedScreen != nil else { return }
        guard self.focusedWindow!.isMovable() else { return }
        guard self.focusedWindow!.frame() != self.focusedScreen!.frame else { return } // fullscreen
        
        let rect = CGRect(
            x: self.placeholderWindow.frame.origin.x - delta.x,
            y: self.placeholderWindow.frame.origin.y + delta.y,
            width: self.placeholderWindow.frame.size.width,
            height: self.placeholderWindow.frame.size.height
        ).fitInVisibleFrame(self.focusedScreen!)
        
        self.placeholderWindow.setFrame(rect, display: true, animate: false)
    }
    
    func onSwipeGesture(gestureOverlayWindow: GestureOverlayWindow, type: GestureType) {
        guard self.focusedWindow != nil else { return }
        guard self.focusedScreen != nil else { return }
        guard self.focusedWindow!.isMovable() else { return } // TODO: Check resizeable also
        guard self.focusedWindow!.frame() != self.focusedScreen!.frame else { return } // fullscreen
        
        var rect: CGRect? = nil
        
        if [GestureType.SWIPE_TOP, GestureType.SWIPE_BOTTOM].contains(type) {
            let newHeight = self.focusedScreen!.visibleFrame.height / 2
            rect = CGRect(
                x: self.focusedScreen!.visibleFrame.origin.x,
                y: self.focusedScreen!.visibleFrame.origin.y + (type == .SWIPE_TOP ? newHeight : 0),
                width: self.focusedScreen!.visibleFrame.width,
                height: newHeight
            )
        } else if [GestureType.SWIPE_LEFT, GestureType.SWIPE_RIGHT].contains(type) {
            let newWidth = self.focusedScreen!.visibleFrame.width / 2
            rect = CGRect(
                x: self.focusedScreen!.visibleFrame.origin.x + (type == .SWIPE_RIGHT ? newWidth : 0),
                y: self.focusedScreen!.visibleFrame.origin.y,
                width: newWidth,
                height: self.focusedScreen!.visibleFrame.height
            )
        } else if [GestureType.SWIPE_TOP_LEFT, GestureType.SWIPE_TOP_RIGHT, GestureType.SWIPE_BOTTOM_LEFT, GestureType.SWIPE_BOTTOM_RIGHT].contains(type) {
            let newHeight = self.focusedScreen!.visibleFrame.height / 2
            let newWidth = self.focusedScreen!.visibleFrame.width / 2
            rect = CGRect(
                x: self.focusedScreen!.visibleFrame.origin.x + (type == .SWIPE_TOP_RIGHT || type == .SWIPE_BOTTOM_RIGHT ? newWidth : 0),
                y: self.focusedScreen!.visibleFrame.origin.y + (type == .SWIPE_TOP_LEFT || type == .SWIPE_TOP_RIGHT ? newHeight : 0),
                width: newWidth,
                height: newHeight
            )
        }
        
        if rect != nil {
            self.placeholderWindow.setFrame(rect!, display: true, animate: false)
        }
    }
    
    func onResizeDeltaGesture(gestureOverlayWindow: GestureOverlayWindow, delta: (x: CGFloat, y: CGFloat)) {
        guard self.focusedWindow != nil else { return }
        guard self.focusedScreen != nil else { return }
        guard self.focusedWindow!.isResizable() else { return }
        guard self.focusedWindow!.frame() != self.focusedScreen!.frame else { return } // fullscreen
        
        let rect = CGRect(
            x: self.placeholderWindow.frame.origin.x + delta.x,
            y: self.placeholderWindow.frame.origin.y + delta.y,
            width: self.placeholderWindow.frame.size.width - (delta.x * 2),
            height: self.placeholderWindow.frame.size.height - (delta.y * 2)
        ).fitInVisibleFrame(self.focusedScreen!)
        
        self.placeholderWindow.setFrame(rect, display: true, animate: false)
    }
    
    func onResizeFactorGesture(gestureOverlayWindow: GestureOverlayWindow, factor: (x: CGFloat, y: CGFloat)) {
        guard self.focusedWindow != nil else { return }
        guard self.focusedScreen != nil else { return }
        guard self.focusedWindow!.isResizable() else { return }
        guard self.focusedWindow!.frame() != self.focusedScreen!.frame else { return } // fullscreen
        
        let delta = (
            x: self.placeholderWindow.frame.size.width * factor.x,
            y: self.placeholderWindow.frame.size.height * factor.y
        )
        let rect = CGRect(
            x: self.placeholderWindow.frame.origin.x + delta.x,
            y: self.placeholderWindow.frame.origin.y + delta.y,
            width: self.placeholderWindow.frame.size.width - (delta.x * 2),
            height: self.placeholderWindow.frame.size.height - (delta.y * 2)
            ).fitInVisibleFrame(self.focusedScreen!)
        
        self.placeholderWindow.setFrame(rect, display: true, animate: false)
    }
    
    
}



