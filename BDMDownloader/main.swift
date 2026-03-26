import Foundation

/// XPC Service entry point.
let delegate = DownloaderService()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()

// Keep the service alive
RunLoop.current.run()
