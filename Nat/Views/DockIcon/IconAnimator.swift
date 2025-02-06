import AppKit
import Combine

final class IconAnimator {
    static let shared = IconAnimator()
    
    private var timer: Timer?
    private var angle: CGFloat = 0
    private var currentSpeed: CGFloat = 0
    private let targetSpeed: CGFloat = 360 // degrees per second
    private let acceleration: CGFloat = 720 / 4 // degrees per second^2
    private var lastUpdate = Date()
    
    private(set) var animRequestCount = 0 {
        didSet {
            animating = animRequestCount > 0
        }
    }
    
    var animating: Bool = false {
        didSet {
            if animating && timer == nil {
                startAnimation()
            } else if !animating {
                currentSpeed = 0
                if let timer = timer {
                    timer.invalidate()
                    self.timer = nil
                }
//                // Reset app icon to default state
//                NSApplication.shared.dockTile.contentView = nil
//                NSApplication.shared.dockTile.display()
            }
        }
    }
    
    private init() {}
    
    func requestAnimation() {
        animRequestCount += 1
    }
    
    func releaseAnimation() {
        animRequestCount = max(0, animRequestCount - 1)
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    private func update() {
        let now = Date()
        let dt = now.timeIntervalSince(lastUpdate)
        lastUpdate = now
        
        // Update speed with acceleration/deceleration
        if animating && currentSpeed < targetSpeed {
            currentSpeed = min(targetSpeed, currentSpeed + acceleration * dt)
        } else if !animating && currentSpeed > 0 {
            currentSpeed = max(0, currentSpeed - acceleration * dt)
        }
        
        // If we've completely stopped, kill the timer
        if currentSpeed == 0 && !animating {
            timer?.invalidate()
            timer = nil
            return
        }
        
        // Update angle and set dock icon
        angle += currentSpeed * dt
        if angle >= 360 { angle -= 360 }
        
        let image = createIconImage(degrees: -angle)
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
        imageView.image = image
        
        NSApplication.shared.dockTile.contentView = imageView
        NSApplication.shared.dockTile.display()
    }
}
