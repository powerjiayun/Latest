//
//  MainWindowController.swift
//  Latest
//
//  Created by Max Langer on 27.02.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Cocoa

/**
 This class controls the main window of the app. It includes the list of apps that have an update available as well as the release notes for the specific update.
 */
class MainWindowController: NSWindowController, NSMenuItemValidation, NSMenuDelegate, UpdateListViewControllerDelegate, UpdateCheckerProgress {
    
    private let ShowInstalledUpdatesKey = "ShowInstalledUpdatesKey"
    
    /// The list view holding the apps
    lazy var listViewController : UpdateTableViewController = {
        guard let splitViewController = self.contentViewController as? NSSplitViewController,
            let firstItem = splitViewController.splitViewItems[0].viewController as? UpdateTableViewController else {
                return UpdateTableViewController()
        }
        
        return firstItem
    }()
    
    /// The detail view controller holding the release notes
    lazy var releaseNotesViewController : ReleaseNotesViewController = {
        guard let splitViewController = self.contentViewController as? NSSplitViewController,
            let secondItem = splitViewController.splitViewItems[1].viewController as? ReleaseNotesViewController else {
                return ReleaseNotesViewController()
        }
        
        return secondItem
    }()
    
    /// The progress indicator showing how many apps have been checked for updates
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    /// The button that triggers an reload/recheck for updates
    @IBOutlet weak var reloadButton: NSButton!
    @IBOutlet weak var reloadTouchBarButton: NSButton!
    
    /// The button thats action opens all apps (or Mac App Store) to begin the update process
    @IBOutlet weak var openAllAppsButton: NSButton!
    @IBOutlet weak var openAllAppsTouchBarButton: NSButton!
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        self.window?.titlebarAppearsTransparent = true
        self.window?.titleVisibility = .hidden
        
        self.showReleaseNotes(false, animated: false)
        
        self.window?.makeFirstResponder(self.listViewController)
        self.window?.delegate = self
        self.setDefaultWindowPosition(for: self.window!)
        
        self.listViewController.updateChecker.progressDelegate = self
        self.listViewController.delegate = self
        self.listViewController.checkForUpdates()
        self.listViewController.releaseNotesViewController = self.releaseNotesViewController
        
        self.updateShowInstalledUpdatesState(with: UserDefaults.standard.bool(forKey: ShowInstalledUpdatesKey))
    }

    
    // MARK: - Action Methods
    
    /// Reloads the list / checks for updates
    @IBAction func reload(_ sender: Any?) {
        self.listViewController.checkForUpdates()
    }
    
    /// Open all apps that have an update available. If apps from the Mac App Store are there as well, open the Mac App Store
    @IBAction func updateAll(_ sender: Any?) {
		self.listViewController.apps.filter({ $0.updateAvailable }).forEach({ $0.update() })
    }
    
    /// Shows/hides the detailView which presents the release notes
    @IBAction func toggleDetail(_ sender: Any?) {
        self.showReleaseNotes(!self.releaseNotesVisible, animated: true)
    }
	
	@IBAction func performFindPanelAction(_ sender: Any?) {
		self.listViewController.searchField.becomeFirstResponder()
	}
    
    @IBAction func toggleShowInstalledUpdates(_ sender: NSMenuItem?) {
        self.updateShowInstalledUpdatesState(with: !UserDefaults.standard.bool(forKey: ShowInstalledUpdatesKey), from: sender)
    }
	
	@IBAction func visitWebsite(_ sender: NSMenuItem?) {
		NSWorkspace.shared.open(URL(string: "https://max.codes/latest")!)
    }
	
	@IBAction func donate(_ sender: NSMenuItem?) {
		NSWorkspace.shared.open(URL(string: "https://max.codes/latest/donate/")!)
	}
    
    
    // MARK: Menu Item Validation

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return true
        }
        
        switch action {
        case #selector(updateAll(_:)):
            return self.listViewController.apps.count != 0
        case #selector(reload(_:)):
            return self.reloadButton.isEnabled
		case #selector(performFindPanelAction(_:)):
			// Only allow the find item
			return menuItem.tag == 1
        default:
            return true
        }
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.forEach { (menuItem) in
            guard let action = menuItem.action else { return }
            
            switch action {
            case #selector(toggleShowInstalledUpdates(_:)):
                menuItem.state = self.listViewController.showInstalledUpdates ? .on : .off
            case #selector(toggleDetail(_:)):
                guard let splitViewController = self.contentViewController as? NSSplitViewController else { return }
                
                let detailItem = splitViewController.splitViewItems[1]
                
                menuItem.title = detailItem.isCollapsed ?
                    NSLocalizedString("Show Version Details", comment: "MenuItem Show Version Details") :
                    NSLocalizedString("Hide Version Details", comment: "MenuItem Hide Version Details")
            default:
                ()
            }
        }
    }
    
    
    // MARK: - Update Checker Progress Delegate
    
    /// This implementation activates the progress indicator, sets its max value and disables the reload button
    func startChecking(numberOfApps: Int) {
        self.reloadButton.isEnabled = false
        self.reloadTouchBarButton.isEnabled = false
    
        self.progressIndicator.doubleValue = 0
        self.progressIndicator.isHidden = false
        self.progressIndicator.maxValue = Double(numberOfApps - 1)
    }
    
    /// Update the progress indicator
    func didCheckApp() {
        self.openAllAppsButton.isEnabled = self.listViewController.apps.countOfAvailableUpdates != 0
        self.openAllAppsTouchBarButton.isEnabled = self.openAllAppsButton.isEnabled
        
        if self.progressIndicator.doubleValue == self.progressIndicator.maxValue {
            self.reloadButton.isEnabled = true
            self.reloadTouchBarButton.isEnabled = true
            self.progressIndicator.isHidden = true
            self.listViewController.finishedCheckingForUpdates()
        } else {
            self.progressIndicator.increment(by: 1)
        }
    }
    
    
    // MARK: - Update List View Controller Delegate

    /// Expands the detail view of the main window
    func shouldExpandDetail() {
        self.showReleaseNotes(true, animated: true)
    }
    
    /// Collapses the detail view of the main window
    func shouldCollapseDetail() {
        self.showReleaseNotes(false, animated: true)
    }
    
    
    // MARK: - Private Methods
    
    /**
     Updates all apps in the array
     - parameter apps: The apps to be updated.
     */
    private func update(_ apps: AppCollection) {
		apps.forEach({ $0.update() })
    }
    
    private func updateShowInstalledUpdatesState(with newState: Bool, from sender: NSMenuItem? = nil) {
        self.listViewController.showInstalledUpdates = newState
    
        if let sender = sender {
            sender.state = newState ? .on : .off
        }
        
        UserDefaults.standard.set(newState, forKey: ShowInstalledUpdatesKey)
    }
    
    private func showReleaseNotes(_ show: Bool, animated: Bool) {
        guard let splitViewController = self.contentViewController as? NSSplitViewController else {
            return
        }
        
        let detailItem = splitViewController.splitViewItems[1]
        
        if animated {
            detailItem.animator().isCollapsed = !show
        } else {
            detailItem.isCollapsed = !show
        }
        
        if !show {
            // Deselect current app
            self.listViewController.selectApp(at: nil)
        }
    }
    
    private var releaseNotesVisible: Bool {
        guard let splitViewController = self.contentViewController as? NSSplitViewController else {
            return false
        }
        
        return !splitViewController.splitViewItems[1].isCollapsed
    }
    
}

extension MainWindowController: NSWindowDelegate {
    
    private static let WindowSizeKey = "WindowSizeKey"
    private static let ReleaseNotesVisible = "ReleaseNotesVisible"

    // This will be called before decodeRestorableState
    func setDefaultWindowPosition(for window: NSWindow) {
        guard let screen = window.screen?.frame else { return }
        
        var rect = NSRect(x: 0, y: 0, width: 360, height: 500)
        rect.origin.x = screen.width / 2 - rect.width / 2
        rect.origin.y = screen.height / 2 - rect.height / 2
        
        window.setFrame(rect, display: true)
    }
    
    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        state.encode(window.frame, forKey: MainWindowController.WindowSizeKey)
        state.encode(self.releaseNotesVisible, forKey: MainWindowController.ReleaseNotesVisible)
    }
    
    func window(_ window: NSWindow, didDecodeRestorableState state: NSCoder) {
        window.setFrame(state.decodeRect(forKey: MainWindowController.WindowSizeKey), display: true)
        self.showReleaseNotes(state.decodeBool(forKey: MainWindowController.ReleaseNotesVisible), animated: false)
    }
	
	func window(_ window: NSWindow, willPositionSheet sheet: NSWindow, using rect: NSRect) -> NSRect {
		// Always position sheets at the top of the window, ignoring toolbar insets
		return NSRect(x: rect.minX, y: window.frame.height, width: rect.width, height: rect.height)
	}
    
}