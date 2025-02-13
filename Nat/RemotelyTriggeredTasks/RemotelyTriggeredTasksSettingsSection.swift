import SwiftUI
import EventKit

struct RemotelyTriggeredTasksSettingsSection: View {
    @AppStorage(DefaultsKeys.pollRemotelyTriggeredTasks.rawValue) private var pollingEnabled = false
    @State private var isShowingFolderPicker = false
    @State private var subscriptions: [RemotelyTriggeredTasksState.Subscription] = []
    
    var body: some View {
        Section(header: Text("Task Reminders")) {
            Toggle("Enable Task Creation from Reminders", isOn: $pollingEnabled)
                .onChange(of: pollingEnabled) { _ in
                    RemotelyTriggeredTasksStore.shared.updatePollingState()
                }
            
            if pollingEnabled {
                FolderList(subscriptions: subscriptions)
                    .onReceive(RemotelyTriggeredTasksStore.shared.publisher.map(\.subscriptions).removeDuplicates()) { subs in
                        self.subscriptions = subs.values.sorted(by: { $0.remindersListName < $1.remindersListName })
                    }
                footer
            }
        }
    }
    
    @ViewBuilder private var footer: some View {
        Button(action: {isShowingFolderPicker = true}) {
            Text("Add Reminders List for Project...")
        }
        .buttonStyle(.plain)
        .fileImporter(isPresented: $isShowingFolderPicker, allowedContentTypes: [.folder]) { result in
            Task { @MainActor in
                do {
                    let url = try result.get()
                    let name = url.lastPathComponent
                    try await RemotelyTriggeredTasksStore.shared.createSubscriptionForFolder(url: url, name: "[\(ProcessInfo.processInfo.processName)] \(name)")
                } catch {
                    await Alerts.showAppAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }

    }
}

private struct FolderList: View {
    let subscriptions: [RemotelyTriggeredTasksState.Subscription]
    
    var body: some View {
        ForEach(subscriptions) { sub in
            FolderEntry(subscription: sub)
        }
    }
}

private struct FolderEntry: View {
    let subscription: RemotelyTriggeredTasksState.Subscription
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(subscription.remindersListName)
                    .fontWeight(.medium)
                Text(subscription.associatedProjectDir.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(role: .destructive) {
                RemotelyTriggeredTasksStore.shared.modify { state in
                    state.subscriptions.removeValue(forKey: subscription.id)
                }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}
