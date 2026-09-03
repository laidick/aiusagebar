import AppKit
import AIUsageBarCore

// `--dump`: one backend fetch, print the lane table as text, exit.
if CommandLine.arguments.contains("--dump") {
    do {
        let table = LaneBuilder.build(try ProcessBackendRunner().fetchSync())
        print(LaneTableText.render(table))
        exit(0)
    } catch {
        let message = (error as? BackendError)?.errorDescription ?? error.localizedDescription
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
