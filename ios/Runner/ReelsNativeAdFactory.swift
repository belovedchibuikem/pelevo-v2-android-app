import Flutter
import GoogleMobileAds
import UIKit
import google_mobile_ads

final class ReelsNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: GADNativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let adView = NativeAdView()
    adView.backgroundColor = .black
    adView.accessibilityLabel = "Sponsored advertisement"

    let mediaView = MediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    mediaView.contentMode = .scaleAspectFill
    adView.addSubview(mediaView)

    let gradient = GradientOverlayView()
    gradient.translatesAutoresizingMaskIntoConstraints = false
    gradient.isUserInteractionEnabled = false
    adView.addSubview(gradient)

    let stack = UIStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .vertical
    stack.alignment = .fill
    stack.spacing = 8
    stack.layoutMargins = UIEdgeInsets(top: 16, left: 20, bottom: 28, right: 20)
    stack.isLayoutMarginsRelativeArrangement = true
    adView.addSubview(stack)

    let sponsored = UILabel()
    sponsored.text = "Sponsored"
    sponsored.textColor = .white
    sponsored.font = .preferredFont(forTextStyle: .caption1).bold()
    sponsored.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    sponsored.numberOfLines = 1
    sponsored.accessibilityLabel = "Sponsored"

    let icon = UIImageView(image: nativeAd.icon?.image)
    icon.contentMode = .scaleAspectFit
    icon.layer.cornerRadius = 8
    icon.clipsToBounds = true
    icon.isHidden = nativeAd.icon == nil
    icon.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      icon.widthAnchor.constraint(equalToConstant: 44),
      icon.heightAnchor.constraint(equalToConstant: 44),
    ])

    let headline = UILabel()
    headline.text = nativeAd.headline
    headline.textColor = .white
    headline.font = .preferredFont(forTextStyle: .title2).bold()
    headline.numberOfLines = 2

    let advertiser = UILabel()
    advertiser.text = nativeAd.advertiser
    advertiser.textColor = .lightGray
    advertiser.font = .preferredFont(forTextStyle: .subheadline)
    advertiser.numberOfLines = 1
    advertiser.isHidden = nativeAd.advertiser == nil

    let body = UILabel()
    body.text = nativeAd.body
    body.textColor = .lightGray
    body.font = .preferredFont(forTextStyle: .body)
    body.numberOfLines = 3
    body.isHidden = nativeAd.body == nil

    let callToAction = UIButton(type: .system)
    callToAction.setTitle(nativeAd.callToAction ?? "Learn more", for: .normal)
    callToAction.setTitleColor(.white, for: .normal)
    callToAction.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    callToAction.backgroundColor = UIColor(red: 124 / 255, green: 58 / 255, blue: 237 / 255, alpha: 1)
    callToAction.layer.cornerRadius = 24
    callToAction.translatesAutoresizingMaskIntoConstraints = false
    callToAction.heightAnchor.constraint(equalToConstant: 50).isActive = true

    [sponsored, icon, headline, advertiser, body, callToAction].forEach(stack.addArrangedSubview)

    let adChoices = AdChoicesView()
    adChoices.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(adChoices)

    NSLayoutConstraint.activate([
      mediaView.topAnchor.constraint(equalTo: adView.topAnchor),
      mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      mediaView.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
      gradient.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      gradient.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      gradient.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
      gradient.heightAnchor.constraint(equalTo: adView.heightAnchor, multiplier: 0.42),
      stack.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      stack.bottomAnchor.constraint(equalTo: adView.safeAreaLayoutGuide.bottomAnchor),
      adChoices.topAnchor.constraint(equalTo: adView.safeAreaLayoutGuide.topAnchor, constant: 4),
      adChoices.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -4),
    ])

    adView.mediaView = mediaView
    adView.headlineView = headline
    adView.advertiserView = advertiser
    adView.bodyView = body
    adView.callToActionView = callToAction
    adView.iconView = icon
    adView.adChoicesView = adChoices
    adView.nativeAd = nativeAd
    return adView
  }
}

private final class GradientOverlayView: UIView {
  override class var layerClass: AnyClass { CAGradientLayer.self }

  override init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configure()
  }

  private func configure() {
    guard let gradient = layer as? CAGradientLayer else { return }
    gradient.colors = [
      UIColor.clear.cgColor,
      UIColor.black.withAlphaComponent(0.85).cgColor,
    ]
    gradient.locations = [0, 1]
  }
}

private extension UIFont {
  func bold() -> UIFont {
    UIFont(descriptor: fontDescriptor.withSymbolicTraits(.traitBold) ?? fontDescriptor, size: pointSize)
  }
}
