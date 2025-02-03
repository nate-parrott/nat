import SwiftUI
import SwiftTerm
import AppKit

extension Array where Element: Equatable {
    func hasPrefix(_ prefix: [Element]) -> Bool {
        count >= prefix.count && Array(self[0..<prefix.count]) == prefix
    }
}

enum TerminalError: Error {
    case alreadyRunning
    case timedOut
}

open class ScriptableTerminalView: TerminalView, TerminalViewDelegate, LocalProcessDelegate {
    var textContent: String {
        String(data: getTerminal().getBufferAsData(), encoding: .utf8)!
            .replacingOccurrences(of: "\0", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func runAndWaitForOutput(command: String, timeout: TimeInterval = 10 * 60) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.main.async {
                if self.onNextBell != nil {
                    cont.resume(throwing: TerminalError.alreadyRunning)
                    return
                }
                let existingLines = self.textContent.components(separatedBy: .newlines)

                var finished = false

                self.onNextBell = {
                    if finished { return }
                    finished = true

                    let newLines = self.textContent.components(separatedBy: .newlines)
                    if newLines.hasPrefix(existingLines) {
                        let output = newLines.dropFirst(existingLines.count).joined(separator: "\n")
                        cont.resume(returning: output)
                    } else {
                        let output = newLines.joined(separator: "\n")
                        cont.resume(returning: output)
                    }
                }
                self.send(txt: command + "\n")
                // Timeout
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                    if !finished {
                        finished = true
                        cont.resume(throwing: TerminalError.timedOut)
                    }
                }
            }
        }
    }

    private var process: LocalProcess!

    init(workingDir: URL) {
        super.init(frame: .init(x: 0, y: 0, width: 600, height: 400))
        terminalDelegate = self
        process = LocalProcess (delegate: self)

        let shell = "/bin/zsh" // getShell()
        let shellIdiom = "-" + NSString(string: shell).lastPathComponent

        FileManager.default.changeCurrentDirectoryPath(workingDir.path) //((FileManager.default.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent("Documents"))
        startProcess (executable: shell, execName: shellIdiom)
        send(txt: "precmd() { echo -n \"\\a\"; }\n")
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /**
     * This method is invoked to notify the client of the new columsn and rows that have been set by the UI
     */
    public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        guard process.running else {
            return
        }
        var size = getWindowSize()
        let _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &size)

//        processDelegate?.sizeChanged (source: self, newCols: newCols, newRows: newRows)
    }

    public func clipboardCopy(source: TerminalView, content: Data) {
        if let str = String (bytes: content, encoding: .utf8) {
            let pasteBoard = NSPasteboard.general
            pasteBoard.clearContents()
            pasteBoard.writeObjects([str as NSString])
        }
    }

    /**
     * Invoke this method to notify the processDelegate of the new title for the terminal window
     */
    public func setTerminalTitle(source: TerminalView, title: String) {
//        processDelegate?.setTerminalTitle (source: self, title: title)
    }

    public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
//        processDelegate?.hostCurrentDirectoryUpdate(source: source as! LocalTermView, directory: directory)
    }


    /**
     * This method is invoked when input from the user needs to be sent to the client
     * Implementation of the TerminalViewDelegate method
     */
    open func send(source: TerminalView, data: ArraySlice<UInt8>)
    {
        process.send (data: data)
    }

    /**
     * Use this method to toggle the logging of data coming from the host, or pass nil to stop
     */
    public func setHostLogging (directory: String?)
    {
        process.setHostLogging (directory: directory)
    }

    /// Implementation of the TerminalViewDelegate method
    open func scrolled(source: TerminalView, position: Double) {
        // noting
    }

    open func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        //
    }

    /**
     * Launches a child process inside a pseudo-terminal.
     * - Parameter executable: The executable to launch inside the pseudo terminal, defaults to /bin/bash
     * - Parameter args: an array of strings that is passed as the arguments to the underlying process
     * - Parameter environment: an array of environment variables to pass to the child process, if this is null, this picks a good set of defaults from `Terminal.getEnvironmentVariables`.
     * - Parameter execName: If provided, this is used as the Unix argv[0] parameter, otherwise, the executable is used as the args [0], this is used when the intent is to set a different process name than the file that backs it.
     */
    public func startProcess(executable: String = "/bin/zsh", args: [String] = [], environment: [String]? = nil, execName: String? = nil)
    {
        process.startProcess(executable: executable, args: args, environment: nil, execName: nil)
    }

    /**
     * Implements the LocalProcessDelegate method.
     */
    open func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
//        processDelegate?.processTerminated(source: self, exitCode: exitCode)
    }

    /**
     * Implements the LocalProcessDelegate.dataReceived method
     */
    open func dataReceived(slice: ArraySlice<UInt8>) {
        feed (byteArray: slice)
        capturedData.append(Data(slice))
    }

    /**
     * Implements the LocalProcessDelegate.getWindowSize method
     */
    open func getWindowSize () -> winsize
    {
        let f: CGRect = self.frame
        return winsize(ws_row: UInt16(getTerminal().rows), ws_col: UInt16(getTerminal().cols), ws_xpixel: UInt16 (f.width), ws_ypixel: UInt16 (f.height))
    }

    var onNextBell: (() -> Void)?
    private var gotFirstBellYet = false // we want to skip it

    public func bell(source: TerminalView) {
        if !gotFirstBellYet {
            gotFirstBellYet = true
            return
        }
        if let b = onNextBell {
            onNextBell = nil
            b()
        }
    }

    var capturedData = Data()
}

struct ScriptableTerminalViewRepresentable: NSViewRepresentable {
    var terminal: ScriptableTerminalView
    // Written by Phil
    func makeNSView(context: Context) -> ScriptableTerminalView {
        return terminal
    }

    func updateNSView(_ nsView: ScriptableTerminalView, context: Context) {
        // No update necessary for now
    }
}

struct TerminalThumbnail: View {
    @Environment(\.document) private var document: Document

    var body: some View {
        WithSnapshotMain(store: document.store, snapshot: { $0.terminalVisible }) { vis in
            if vis, let term = document.terminal {
                ScriptableTerminalViewRepresentable(terminal: term)
                    .frame(width: 600, height: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 2)
                    }
                    .scaleEffect(0.4, anchor: .bottomTrailing)
                    .allowsHitTesting(false)
            }
        }
        .padding()
    }
}

struct TerminalPreview: View {
    @Environment(\.document) private var document: Document
    
    var body: some View {
        WithSnapshotMain(store: document.store, snapshot: { $0.terminalVisible }) { vis in
            if vis, let term = document.terminal {
                ScriptableTerminalViewRepresentable(terminal: term)
            } else {
                Color.black
                    .overlay {
                        Text("No terminal running")
                            .fontDesign(.monospaced)
                            .foregroundStyle(.white)
                            .opacity(0.4)
                    }
            }
        } // TODO: fixed size for terminal?

    }
}
