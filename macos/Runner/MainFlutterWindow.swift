import Cocoa
import FlutterMacOS
import CoreLocation
import CoreWLAN

class MainFlutterWindow: NSWindow {
  let location = CLLocationManager()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // 最初は 1200x800 で画面の中央に。コート全体と操作説明が収まる大きさより小さくはしない
    self.setContentSize(NSSize(width: 1200, height: 800))
    self.contentMinSize = NSSize(width: 980, height: 680)
    self.title = "PODLE!"
    self.center()

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

    super.awakeFromNib()
  }
}
