import CoreLocation
import Flutter
import Foundation

/// Native driver GPS. Not a Flutter background-location plugin.
final class BackgroundLocationManager: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var last: CLLocation?
  private var minDisplacement: CLLocationDistance = 10

  override init() {
    super.init()
    manager.delegate = self
    manager.allowsBackgroundLocationUpdates = true
    manager.pausesLocationUpdatesAutomatically = false
    manager.desiredAccuracy = kCLLocationAccuracyBest
  }

  func start(intervalMs: Int, displacementM: Double) {
    minDisplacement = displacementM
    manager.distanceFilter = displacementM
    manager.requestAlwaysAuthorization()
    manager.startUpdatingLocation()
  }

  func stop() {
    manager.stopUpdatingLocation()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let loc = locations.last else { return }
    if let prev = last, loc.distance(from: prev) < minDisplacement { return }
    last = loc
  }
}
