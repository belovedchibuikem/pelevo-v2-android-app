import AVKit
import Flutter
import UIKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  deinit {
    FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(
      self,
      factoryId: "pelevoReelsNative"
    )
    FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(
      self,
      factoryId: "pelevoHomeNative"
    )
    FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(
      self,
      factoryId: "pelevoSearchNative"
    )
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: "pelevoReelsNative",
      nativeAdFactory: ReelsNativeAdFactory()
    )
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: "pelevoHomeNative",
      nativeAdFactory: HomeFeedNativeAdFactory()
    )
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      self,
      factoryId: "pelevoSearchNative",
      nativeAdFactory: SearchNativeAdFactory()
    )
    if let registrar = self.registrar(forPlugin: "PelevoAirPlay") {
      registrar.register(
        AirPlayRoutePickerFactory(),
        withId: "pelevo/airplay_route_picker"
      )
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

final class AirPlayRoutePickerFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    AirPlayRoutePicker(frame: frame)
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol) {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class AirPlayRoutePicker: NSObject, FlutterPlatformView {
  private let picker: AVRoutePickerView

  init(frame: CGRect) {
    picker = AVRoutePickerView(frame: frame)
    picker.tintColor = UIColor.label
    picker.activeTintColor = UIColor.systemGreen
    picker.prioritizesVideoDevices = false
    super.init()
  }

  func view() -> UIView {
    picker
  }
}
