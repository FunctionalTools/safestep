import CoreMotion
import Combine
import Foundation

final class MotionDetectorV2: ObservableObject {
    @Published var isRed = false
    
    private let motionManager = CMMotionManager()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let accelerationThreshold: Double = 2.5
    private let detectionInterval: TimeInterval = 0.1
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func reset() {
        isRed = false
    }
    
    private func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = detectionInterval
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            let magnitude = self.vectorMagnitude(x: data.acceleration.x,
                                                 y: data.acceleration.y,
                                                 z: data.acceleration.z)
            if magnitude > self.accelerationThreshold {
                self.isRed = true
                self.stopMonitoring()
            }
        }
    }
    
    private func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        timer?.invalidate()
        timer = nil
    }
    
    private func vectorMagnitude(x: Double, y: Double, z: Double) -> Double {
        return sqrt(x * x + y * y + z * z)
    }
}
