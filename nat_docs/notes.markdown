tests are in NatsTests/

Run tests using scheme Nat

In UI code, use things like onReceive or WithSnapshotMain to observe the document store reactively, rather than just viewing the document store’s model once.

Tools for the main agent are registered in ChatView.swift

When calling external processes, make sure to read the file data BEFORE calling waitUntilExit:

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["ls-files", "--cached", "--others", "--exclude-standard"]
        process.currentDirectoryURL = url
        
        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            guard let data = try pipe.fileHandleForReading.readToEnd() else {
                throw FileTreeError.noData
            }
            process.waitUntilExit()
