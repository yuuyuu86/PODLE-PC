import Cocoa
import FlutterMacOS
import CoreLocation
import CoreWLAN

class MainFlutterWindow: NSWindow {
  let location = CLLocationManager()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // 小さい画面でも画面いっぱいに収まるよう、最小の大きさは小さめにしておく
    self.setContentSize(NSSize(width: 1200, height: 800))
    self.contentMinSize = NSSize(width: 640, height: 480)
    self.title = "PODLE!"
    // 画面いっぱいに広げ、大きさを変えられないようにする（2台のコートの大きさをそろえるため）
    self.maximizeToScreen()
    NotificationCenter.default.addObserver(forName: NSWindow.didChangeScreenNotification, object: self, queue: .main) { [weak self] _ in
      self?.maximizeToScreen()
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 今つながっている Wi-Fi の名前。macOS では位置情報の許可がないと名前を読めないので、初めて聞かれたときに許可を求める
    let wifi = FlutterMethodChannel(name: "podle/wifi", binaryMessenger: flutterViewController.engine.binaryMessenger)
    wifi.setMethodCallHandler { [weak self] call, result in
      guard call.method == "ssid" else { return result(FlutterMethodNotImplemented) }
      guard let self = self else { return result(nil) }
      if self.location.authorizationStatus == .notDetermined {
        self.location.requestWhenInUseAuthorization()
      }
      result(CWWiFiClient.shared().interface()?.ssid())
    }

    // 画面の実際の大きさ（1ポイントあたり何ミリか）。2台のコートを実寸でそろえるのに使う
    let screen = FlutterMethodChannel(name: "podle/screen", binaryMessenger: flutterViewController.engine.binaryMessenger)
    screen.setMethodCallHandler { [weak self] call, result in
      guard call.method == "mmPerPoint", let s = self?.screen ?? NSScreen.main,
            let id = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return result(nil) }
      let mm = CGDisplayScreenSize(id)
      if mm.width <= 0 || s.frame.width <= 0 { return result(nil) }
      result(Double(mm.width / s.frame.width))
    }

    super.awakeFromNib()
  }

  func maximizeToScreen() {
    guard let s = self.screen ?? NSScreen.main else { return }
    self.styleMask.insert(.resizable)
    self.setFrame(s.visibleFrame, display: true)
    self.styleMask.remove(.resizable)
  }
}
