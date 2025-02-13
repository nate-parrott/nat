import Foundation
import EventKit

/*
 This feature allows us to trigger new tasks via the Reminders system.
 The user uses a UI to set up an association between a particular project folder URL and a reminders list.
 (In the UI, we ask the user to choose a folder, then we create a reminders list for them using the name of the folder, like "[Nat] Project Name")
 
 TODO: Implement settings screen to allow creating and deleting these folder/reminder list associations, plus a toggle to turn on/off polling (this should be persistent, stored in userDefaults per DefaultsKeys, but we also need to make sure to
 
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
    
    override init(persistenceKey: String?, defaultModel: RemotelyTriggeredTasksState, queue: Queue) {
        // TODO: set up observer for DefaultsKeys.pollRemotelyTriggeredTasks and set pollingEnabled based on it
        super.init(persistenceKey: persistenceKey, defaultModel: defaultModel, queue: queue)
    }
    
    private var pollingEnabled = false {
        didSet {
            // TODO
        }
    }
    
    func pollReminders() {
        
    }
    
    func beginTask(reminder: EKReminder) {
        // Checks if task already in processedItems -- if so, quit. Otherwise, create a new Document via DocumentController.shared.createUntitled, set its folder, then send initial message while requesting worktree
        // Then mark reminder as completed
    }
}
