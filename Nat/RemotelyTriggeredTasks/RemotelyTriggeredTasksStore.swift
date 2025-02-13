import Foundation
import EventKit
import os.log
import AppKit

/*
 This feature allows us to trigger new tasks via the Reminders system.
 The user uses a UI to set up an association between a particular project folder URL and a reminders list.
 (In the UI, we ask the user to choose a folder, then we create a reminders list for them using the name of the folder, like "[Nat] Project Name")
  
 Then, if pollingEnabled is true, we periodically poll the reminders system. If any of our tracked lists gets a new item that is NOT completed, and not present in processedItems, we mark it as done and begin a task to do the work.
 
 See here: https://developer.apple.com/documentation/eventkit/retrieving-events-and-reminders
 
 Here is an example of how to start a task agent:
 
 Task { @MainActor in
     do {
         let doc = try! NSDocumentController.shared.openUntitledDocumentAndDisplay(true) as! Document
         doc.store.modify { state in
             state.folder = URL(fileURLWithPath: "/Users/nparrott/Documents/SW/taylor")
             state.autorun = true
         }
         let prompt = "Read this codebase and tell me a bit about it"
         _ = try await doc.tryEnterWorktreeMode(initialPrompt: prompt)
         await doc.send(text: prompt, attachments: [])
     } catch {
         await Alerts.showAppAlert(title: "Error starting task", message: "\(error)")
     }
 }
 */

struct RemotelyTriggeredTasksState: Equatable, Codable {
    struct Subscription: Equatable, Codable, Identifiable {
        var id: String
        var remindersListName: String
        var associatedProjectDir: URL
        var processedItems = Set<String>() // EKReminder calendarItemIdentifier corresponding to tasks we've begun
    }
    
    var subscriptions = [String: Subscription]()
}

class RemotelyTriggeredTasksStore: DataStore<RemotelyTriggeredTasksState> {
    static let shared = RemotelyTriggeredTasksStore(persistenceKey: "RemotelyTriggeredTasks", defaultModel: .init(), queue: .main)
    private let store = EKEventStore()
    private var timer: Timer?
    private var observerToken: NSObjectProtocol?
    private var pollingEnabled = false
    
    override func setup() {
        super.setup()
        observerToken = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updatePollingState()
        }
        updatePollingState()
    }
    
    deinit {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
        }
        timer?.invalidate()
    }
    
    func updatePollingState() {
        let enabled = DefaultsKeys.pollRemotelyTriggeredTasks.boolValue()
        os_log(.info, "RemotelyTriggeredTasks polling state changed to: %{public}@", "\(enabled)")
        
        if enabled != pollingEnabled {
            pollingEnabled = enabled
            if enabled {
                requestAccess()
                setupPolling()
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    enum Errors: Error {
        case noCalendar
        case fetchFailed
    }
    
    func createSubscriptionForFolder(url: URL, name: String) async throws {
        try await store.requestFullAccessToReminders()
        let id = UUID().uuidString
        
        // Show first-time explanation
        if !DefaultsKeys.hasSeenRemindersExplanation.boolValue() {
            UserDefaults.standard.set(true, forKey: DefaultsKeys.hasSeenRemindersExplanation.rawValue)
            await Alerts.showAppAlert(
                title: "Reminders Integration",
                message: "A new list will be created in your Reminders app. Add tasks to this list from your phone or other devices, and Nat will automatically start working on them."
            )
        }
        
        // Create a new list for this folder
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = name
        guard let source = store.defaultCalendarForNewReminders()?.source else {
            throw Errors.noCalendar
        }
        list.source = source
        try store.saveCalendar(list, commit: true)
        
        // Save subscription in our DataStore
        modify { state in
            state.subscriptions[id] = .init(
                id: id,
                remindersListName: name,
                associatedProjectDir: url
            )
        }
    }
    
    private func requestAccess() {
        Task { @MainActor in
            do {
                try await store.requestFullAccessToReminders()
            } catch {
                os_log(.error, "Failed to get reminders access: %{public}@", error.localizedDescription)
                await Alerts.showAppAlert(title: "Error", message: "Please grant access to Reminders in System Settings")
            }
        }
    }
    
    private func setupPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            self?.pollReminders()
        }
        timer?.tolerance = 60
        pollReminders() // Initial polls
    }
    
    private func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        return try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                if let reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: Errors.fetchFailed)
                }
            }
        }
    }
    
    private func pollReminders() {
        guard pollingEnabled else { return }
        
        let calendars = store.calendars(for: .reminder)
        let subs = model.subscriptions
        os_log(.info, "Polling reminders for %d subscriptions...", subs.count)
        
        Task { @MainActor in
            for sub in subs.values {
                guard let calendar = calendars.first(where: { $0.title == sub.remindersListName }) else {
                    os_log(.error, "Could not find calendar named: %{public}@", sub.remindersListName)
                    continue
                }
                
                let predicate = store.predicateForIncompleteReminders(
                    withDueDateStarting: nil,
                    ending: nil,
                    calendars: [calendar]
                )
                
                do {
                    let reminders = try await fetchReminders(matching: predicate)
                    for reminder in reminders {
                        if !sub.processedItems.contains(reminder.calendarItemIdentifier) {
                            os_log(.info, "Found new reminder: %{public}@", reminder.title)
                            beginTask(reminder: reminder, subscription: sub)
                        }
                    }
                } catch {
                    os_log(.error, "Failed to fetch reminders: %{public}@", error.localizedDescription)
                }
            }
        }
    }
    
    private func beginTask(reminder: EKReminder, subscription: RemotelyTriggeredTasksState.Subscription) {
        Task { @MainActor in
            do {
                // Mark as done first to avoid duplicate tasks if something fails
                reminder.isCompleted = true
                try store.save(reminder, commit: true)
                
                modify { state in
                    state.subscriptions[subscription.id]?.processedItems.insert(reminder.calendarItemIdentifier)
                }
                
                // Create the document 
                let doc = try! NSDocumentController.shared.openUntitledDocumentAndDisplay(true) as! Document
                doc.store.modify { state in
                    state.folder = subscription.associatedProjectDir
                    state.autorun = true
                }
                
                // Start the task
                _ = try await doc.tryEnterWorktreeMode(initialPrompt: reminder.title)
                await doc.send(text: reminder.title, attachments: [])
                
            } catch {
                os_log(.error, "Failed to start task: %{public}@", error.localizedDescription)
                await Alerts.showAppAlert(title: "Error starting task", message: "\(error)")
            }
        }
    }
}
