import Flutter
import GoogleMobileAds
import UIKit
import google_mobile_ads

private let feedMuted = UIColor(red: 160 / 255, green: 160 / 255, blue: 160 / 255, alpha: 1)
private let feedGreen = UIColor(red: 47 / 255, green: 164 / 255, blue: 79 / 255, alpha: 1)
private let feedCard = UIColor(red: 18 / 255, green: 18 / 255, blue: 18 / 255, alpha: 1)
private let feedWell = UIColor(white: 0.12, alpha: 1)

final class HomeFeedNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let adView = NativeAdView()
    adView.backgroundColor = feedCard
    adView.layer.cornerRadius = 12
    adView.clipsToBounds = true
    adView.accessibilityLabel = "Sponsored advertisement"

    let root = UIStackView()
    root.translatesAutoresizingMaskIntoConstraints = false
    root.axis = .vertical
    root.spacing = 8
    root.isLayoutMarginsRelativeArrangement = true
    root.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    adView.addSubview(root)

    let icon = UIImageView(image: nativeAd.icon?.image)
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.contentMode = .scaleAspectFill
    icon.clipsToBounds = true
    icon.layer.cornerRadius = 8
    icon.backgroundColor = feedWell
    NSLayoutConstraint.activate([
      icon.widthAnchor.constraint(equalToConstant: 36),
      icon.heightAnchor.constraint(equalToConstant: 36),
    ])

    let headline = UILabel()
    headline.text = nativeAd.headline
    headline.textColor = .white
    headline.font = .systemFont(ofSize: 14, weight: .bold)
    headline.numberOfLines = 1
    headline.lineBreakMode = .byTruncatingTail

    let body = UILabel()
    body.text = nativeAd.body
    body.textColor = feedMuted
    body.font = .systemFont(ofSize: 12, weight: .regular)
    body.numberOfLines = 2
    body.lineBreakMode = .byTruncatingTail

    let textColumn = UIStackView(arrangedSubviews: [headline, body])
    textColumn.axis = .vertical
    textColumn.spacing = 2
    textColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)

    let sponsored = UILabel()
    sponsored.text = "Sponsored"
    sponsored.textColor = feedMuted
    sponsored.font = .systemFont(ofSize: 10, weight: .regular)
    sponsored.setContentHuggingPriority(.required, for: .horizontal)
    sponsored.setContentCompressionResistancePriority(.required, for: .horizontal)

    let header = UIStackView(arrangedSubviews: [icon, textColumn, sponsored])
    header.axis = .horizontal
    header.alignment = .center
    header.spacing = 8

    let mediaFrame = UIView()
    mediaFrame.clipsToBounds = true
    mediaFrame.layer.cornerRadius = 8
    mediaFrame.backgroundColor = feedWell
    mediaFrame.setContentHuggingPriority(.defaultLow, for: .vertical)
    mediaFrame.setContentCompressionResistancePriority(.required, for: .vertical)
    mediaFrame.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true

    let media = MediaView()
    media.translatesAutoresizingMaskIntoConstraints = false
    media.contentMode = .scaleAspectFill
    mediaFrame.addSubview(media)

    let adChoices = AdChoicesView()
    adChoices.translatesAutoresizingMaskIntoConstraints = false
    mediaFrame.addSubview(adChoices)
    NSLayoutConstraint.activate([
      media.topAnchor.constraint(equalTo: mediaFrame.topAnchor),
      media.leadingAnchor.constraint(equalTo: mediaFrame.leadingAnchor),
      media.trailingAnchor.constraint(equalTo: mediaFrame.trailingAnchor),
      media.bottomAnchor.constraint(equalTo: mediaFrame.bottomAnchor),
      adChoices.topAnchor.constraint(equalTo: mediaFrame.topAnchor, constant: 4),
      adChoices.trailingAnchor.constraint(equalTo: mediaFrame.trailingAnchor, constant: -4),
    ])

    let callToAction = UIButton(type: .custom)
    callToAction.setTitle(nativeAd.callToAction ?? "Learn more", for: .normal)
    callToAction.setTitleColor(.black, for: .normal)
    callToAction.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
    callToAction.backgroundColor = feedGreen
    callToAction.layer.cornerRadius = 8
    callToAction.translatesAutoresizingMaskIntoConstraints = false
    callToAction.heightAnchor.constraint(equalToConstant: 36).isActive = true

    root.addArrangedSubview(header)
    root.addArrangedSubview(mediaFrame)
    root.addArrangedSubview(callToAction)
    NSLayoutConstraint.activate([
      root.topAnchor.constraint(equalTo: adView.topAnchor),
      root.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      root.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      root.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
    ])

    adView.iconView = icon
    adView.headlineView = headline
    adView.bodyView = body
    adView.mediaView = media
    adView.callToActionView = callToAction
    adView.adChoicesView = adChoices
    adView.nativeAd = nativeAd
    body.isHidden = nativeAd.body?.isEmpty ?? true
    icon.isHidden = nativeAd.icon == nil
    return adView
  }
}

final class SearchNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let adView = NativeAdView()
    adView.backgroundColor = .clear
    adView.accessibilityLabel = "Sponsored advertisement"

    let row = UIStackView()
    row.translatesAutoresizingMaskIntoConstraints = false
    row.axis = .horizontal
    row.alignment = .center
    row.spacing = 12
    adView.addSubview(row)

    let iconFrame = UIView()
    iconFrame.translatesAutoresizingMaskIntoConstraints = false
    let icon = UIImageView(image: nativeAd.icon?.image)
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.contentMode = .scaleAspectFill
    icon.clipsToBounds = true
    icon.layer.cornerRadius = 8
    icon.backgroundColor = feedWell
    iconFrame.addSubview(icon)

    let adChoices = AdChoicesView()
    adChoices.translatesAutoresizingMaskIntoConstraints = false
    iconFrame.addSubview(adChoices)
    NSLayoutConstraint.activate([
      iconFrame.widthAnchor.constraint(equalToConstant: 56),
      iconFrame.heightAnchor.constraint(equalToConstant: 56),
      icon.topAnchor.constraint(equalTo: iconFrame.topAnchor),
      icon.leadingAnchor.constraint(equalTo: iconFrame.leadingAnchor),
      icon.trailingAnchor.constraint(equalTo: iconFrame.trailingAnchor),
      icon.bottomAnchor.constraint(equalTo: iconFrame.bottomAnchor),
      adChoices.topAnchor.constraint(equalTo: iconFrame.topAnchor),
      adChoices.trailingAnchor.constraint(equalTo: iconFrame.trailingAnchor),
    ])

    let headline = UILabel()
    headline.text = nativeAd.headline
    headline.textColor = .white
    headline.font = .systemFont(ofSize: 14, weight: .bold)
    headline.numberOfLines = 1
    headline.lineBreakMode = .byTruncatingTail

    let advertiser = UILabel()
    advertiser.text = nativeAd.advertiser
    advertiser.textColor = feedMuted
    advertiser.font = .systemFont(ofSize: 12, weight: .regular)
    advertiser.numberOfLines = 1
    advertiser.lineBreakMode = .byTruncatingTail
    advertiser.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    advertiser.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let badge = UILabel()
    badge.textColor = feedMuted
    badge.font = .systemFont(ofSize: 12, weight: .regular)
    badge.setContentHuggingPriority(.required, for: .horizontal)
    badge.setContentCompressionResistancePriority(.required, for: .horizontal)

    let subtitle = UIStackView(arrangedSubviews: [advertiser, badge])
    subtitle.axis = .horizontal
    subtitle.alignment = .center
    subtitle.spacing = 4

    let textColumn = UIStackView(arrangedSubviews: [headline, subtitle])
    textColumn.axis = .vertical
    textColumn.spacing = 2
    textColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)

    let callToAction = UIButton(type: .custom)
    var buttonConfig = UIButton.Configuration.filled()
    buttonConfig.title = nativeAd.callToAction ?? "Open"
    buttonConfig.baseForegroundColor = .black
    buttonConfig.baseBackgroundColor = feedGreen
    buttonConfig.cornerStyle = .fixed
    buttonConfig.background.cornerRadius = 8
    buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    buttonConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var outgoing = incoming
      outgoing.font = .systemFont(ofSize: 12, weight: .bold)
      return outgoing
    }
    callToAction.configuration = buttonConfig
    callToAction.translatesAutoresizingMaskIntoConstraints = false
    callToAction.setContentHuggingPriority(.required, for: .horizontal)
    callToAction.setContentCompressionResistancePriority(.required, for: .horizontal)
    callToAction.heightAnchor.constraint(equalToConstant: 32).isActive = true
    callToAction.widthAnchor.constraint(lessThanOrEqualToConstant: 96).isActive = true

    row.addArrangedSubview(iconFrame)
    row.addArrangedSubview(textColumn)
    row.addArrangedSubview(callToAction)
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      row.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      row.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
      row.topAnchor.constraint(greaterThanOrEqualTo: adView.topAnchor),
      row.bottomAnchor.constraint(lessThanOrEqualTo: adView.bottomAnchor),
    ])

    adView.iconView = icon
    adView.headlineView = headline
    adView.advertiserView = advertiser
    adView.callToActionView = callToAction
    adView.adChoicesView = adChoices
    adView.nativeAd = nativeAd
    let hasAdvertiser = !(nativeAd.advertiser?.isEmpty ?? true)
    advertiser.isHidden = !hasAdvertiser
    badge.text = hasAdvertiser ? "· Ad" : "Ad"
    return adView
  }
}
