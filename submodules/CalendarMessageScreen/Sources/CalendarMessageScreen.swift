import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import ComponentFlow
import PhotoResources
import DirectMediaImageCache

private final class MediaPreviewView: UIView {
    private let context: AccountContext
    private let message: EngineMessage
    private let media: EngineMedia
    private let imageCache: DirectMediaImageCache

    private let imageView: UIImageView

    private var requestedImage: Bool = false
    private var disposable: Disposable?

    init(context: AccountContext, message: EngineMessage, media: EngineMedia, imageCache: DirectMediaImageCache) {
        self.context = context
        self.message = message
        self.media = media
        self.imageCache = imageCache

        self.imageView = UIImageView()
        self.imageView.contentMode = .scaleToFill

        super.init(frame: CGRect())

        self.addSubview(self.imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable?.dispose()
    }

    func updateLayout(size: CGSize, synchronousLoads: Bool) {
        let processImage: (UIImage) -> UIImage = { image in
            return generateImage(size, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.addEllipse(in: CGRect(origin: CGPoint(), size: size))
                context.clip()

                UIGraphicsPushContext(context)
                image.draw(in: CGRect(origin: CGPoint(), size: size))
                UIGraphicsPopContext()
            })!
        }

        if !self.requestedImage {
            self.requestedImage = true
            if let result = self.imageCache.getImage(message: self.message._asMessage(), media: self.media._asMedia(), width: 100, possibleWidths: [100], synchronous: false) {
                if let image = result.image {
                    self.imageView.image = processImage(image)
                }
                if let signal = result.loadSignal {
                    self.disposable = (signal
                    |> map { image in
                        return image.flatMap(processImage)
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] image in
                        guard let strongSelf = self else {
                            return
                        }
                        if let image = image {
                            if strongSelf.imageView.image != nil {
                                let tempView = UIImageView()
                                tempView.image = strongSelf.imageView.image
                                tempView.frame = strongSelf.imageView.frame
                                tempView.contentMode = strongSelf.imageView.contentMode
                                strongSelf.addSubview(tempView)
                                tempView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak tempView] _ in
                                    tempView?.removeFromSuperview()
                                })
                            }
                            strongSelf.imageView.image = image
                        }
                    })
                }
            }
        }

        self.imageView.frame = CGRect(origin: CGPoint(), size: size)
        /*var dimensions = CGSize(width: 100.0, height: 100.0)
        if case let .image(image) = self.media {
            if let largest = largestImageRepresentation(image.representations) {
                dimensions = largest.dimensions.cgSize
                if !self.requestedImage {
                    self.requestedImage = true
                    let signal = mediaGridMessagePhoto(account: self.context.account, photoReference: .message(message: MessageReference(self.message._asMessage()), media: image), fullRepresentationSize: CGSize(width: 36.0, height: 36.0), synchronousLoad: synchronousLoads)
                    self.imageView.setSignal(signal, attemptSynchronously: synchronousLoads)
                }
            }
        } else if case let .file(file) = self.media {
            if let mediaDimensions = file.dimensions {
                dimensions = mediaDimensions.cgSize
                if !self.requestedImage {
                    self.requestedImage = true
                    let signal = mediaGridMessageVideo(postbox: self.context.account.postbox, videoReference: .message(message: MessageReference(self.message._asMessage()), media: file), synchronousLoad: synchronousLoads, autoFetchFullSizeThumbnail: true, useMiniThumbnailIfAvailable: true)
                    self.imageView.setSignal(signal, attemptSynchronously: synchronousLoads)
                }
            }
        }

        let makeLayout = self.imageView.asyncLayout()
        self.imageView.frame = CGRect(origin: CGPoint(), size: size)
        let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: size.width / 2.0), imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
        apply()*/
    }
}

private func monthName(index: Int, strings: PresentationStrings) -> String {
    switch index {
    case 0:
        return strings.Month_GenJanuary
    case 1:
        return strings.Month_GenFebruary
    case 2:
        return strings.Month_GenMarch
    case 3:
        return strings.Month_GenApril
    case 4:
        return strings.Month_GenMay
    case 5:
        return strings.Month_GenJune
    case 6:
        return strings.Month_GenJuly
    case 7:
        return strings.Month_GenAugust
    case 8:
        return strings.Month_GenSeptember
    case 9:
        return strings.Month_GenOctober
    case 10:
        return strings.Month_GenNovember
    case 11:
        return strings.Month_GenDecember
    default:
        return ""
    }
}

private func dayName(index: Int, strings: PresentationStrings) -> String {
    let _ = strings
    //TODO:localize

    switch index {
    case 0:
        return "M"
    case 1:
        return "T"
    case 2:
        return "W"
    case 3:
        return "T"
    case 4:
        return "F"
    case 5:
        return "S"
    case 6:
        return "S"
    default:
        return ""
    }
}

private class Scroller: UIScrollView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }

    @objc func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

private final class ImageCache: Equatable {
    static func ==(lhs: ImageCache, rhs: ImageCache) -> Bool {
        return lhs === rhs
    }

    private struct FilledCircle: Hashable {
        var diameter: CGFloat
        var innerDiameter: CGFloat?
        var color: UInt32
    }

    private struct Text: Hashable {
        var fontSize: CGFloat
        var isSemibold: Bool
        var color: UInt32
        var string: String
    }

    private struct MonthSelection: Hashable {
        var leftRadius: CGFloat
        var rightRadius: CGFloat
        var maxRadius: CGFloat
        var color: UInt32
    }

    private var items: [AnyHashable: UIImage] = [:]

    func filledCircle(diameter: CGFloat, innerDiameter: CGFloat?, color: UIColor) -> UIImage {
        let key = AnyHashable(FilledCircle(diameter: diameter, innerDiameter: innerDiameter, color: color.argb))
        if let image = self.items[key] {
            return image
        }
        let image = generateImage(CGSize(width: diameter, height: diameter), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))

            context.setFillColor(color.cgColor)

            context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))

            if let innerDiameter = innerDiameter {
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: (size.width - innerDiameter) / 2.0, y: (size.height - innerDiameter) / 2.0), size: CGSize(width: innerDiameter, height: innerDiameter)))
            }
        })!.stretchableImage(withLeftCapWidth: Int(diameter) / 2, topCapHeight: Int(diameter) / 2)
        self.items[key] = image
        return image
    }

    func text(fontSize: CGFloat, isSemibold: Bool, color: UIColor, string: String) -> UIImage {
        let key = AnyHashable(Text(fontSize: fontSize, isSemibold: isSemibold, color: color.argb, string: string))
        if let image = self.items[key] {
            return image
        }

        let font: UIFont
        if isSemibold {
            font = Font.semibold(fontSize)
        } else {
            font = Font.regular(fontSize)
        }
        let attributedString = NSAttributedString(string: string, font: font, textColor: color)
        var rect = attributedString.boundingRect(with: CGSize(width: 1000.0, height: 1000.0), options: .usesLineFragmentOrigin, context: nil)
        if string == "1" {
            rect.origin.x -= 1.0
        }
        let image = generateImage(CGSize(width: ceil(rect.width), height: ceil(rect.height)), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))

            UIGraphicsPushContext(context)
            attributedString.draw(in: rect)
            UIGraphicsPopContext()
        })!
        self.items[key] = image
        return image
    }

    func monthSelection(leftRadius: CGFloat, rightRadius: CGFloat, maxRadius: CGFloat, color: UIColor) -> UIImage {
        let key = AnyHashable(MonthSelection(leftRadius: leftRadius, rightRadius: rightRadius, maxRadius: maxRadius, color: color.argb))
        if let image = self.items[key] {
            return image
        }

        let image = generateImage(CGSize(width: maxRadius, height: maxRadius), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(color.cgColor)

            UIGraphicsPushContext(context)

            context.clip(to: CGRect(origin: CGPoint(), size: CGSize(width: size.width / 2.0, height: size.height)))
            UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: leftRadius).fill()

            context.resetClip()
            context.clip(to: CGRect(origin: CGPoint(x: size.width / 2.0, y: 0.0), size: CGSize(width: size.width - size.width / 2.0, height: size.height)))
            UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: rightRadius).fill()

            UIGraphicsPopContext()
        })!.stretchableImage(withLeftCapWidth: Int(maxRadius / 2.0), topCapHeight: Int(maxRadius / 2.0))
        self.items[key] = image
        return image
    }
}

private final class DayEnvironment: Equatable {
    let imageCache: ImageCache
    let directImageCache: DirectMediaImageCache

    init(imageCache: ImageCache, directImageCache: DirectMediaImageCache) {
        self.imageCache = imageCache
        self.directImageCache = directImageCache
    }

    static func ==(lhs: DayEnvironment, rhs: DayEnvironment) -> Bool {
        return lhs === rhs
    }
}

private final class ImageComponent: Component {
    let image: UIImage?

    init(
        image: UIImage?
    ) {
        self.image = image
    }

    static func ==(lhs: ImageComponent, rhs: ImageComponent) -> Bool {
        if lhs.image !== rhs.image {
            return false
        }
        return true
    }

    final class View: UIImageView {
        init() {
            super.init(frame: CGRect())
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: ImageComponent, availableSize: CGSize, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.image = component.image

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private final class DayComponent: Component {
    typealias EnvironmentType = DayEnvironment

    enum DaySelection {
        case none
        case edge
        case middle
    }

    let title: String
    let isCurrent: Bool
    let isEnabled: Bool
    let theme: PresentationTheme
    let context: AccountContext
    let media: DayMedia?
    let selection: DaySelection
    let isSelecting: Bool
    let action: () -> Void

    init(
        title: String,
        isCurrent: Bool,
        isEnabled: Bool,
        theme: PresentationTheme,
        context: AccountContext,
        media: DayMedia?,
        selection: DaySelection,
        isSelecting: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isCurrent = isCurrent
        self.isEnabled = isEnabled
        self.theme = theme
        self.context = context
        self.media = media
        self.selection = selection
        self.isSelecting = isSelecting
        self.action = action
    }

    static func ==(lhs: DayComponent, rhs: DayComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.isCurrent != rhs.isCurrent {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.media != rhs.media {
            return false
        }
        if lhs.selection != rhs.selection {
            return false
        }
        if lhs.isSelecting != rhs.isSelecting {
            return false
        }
        return true
    }

    final class View: UIView {
        private let button: HighlightTrackingButton

        private let highlightView: UIImageView
        private var selectionView: UIImageView?
        private let titleView: UIImageView
        private var mediaPreviewView: MediaPreviewView?

        private var action: (() -> Void)?
        private var currentMedia: DayMedia?

        private(set) var index: MessageIndex?
        private var isHighlightingEnabled: Bool = false

        init() {
            self.button = HighlightTrackingButton()
            self.highlightView = UIImageView()
            self.highlightView.isUserInteractionEnabled = false
            self.titleView = UIImageView()
            self.titleView.isUserInteractionEnabled = false

            super.init(frame: CGRect())

            self.button.addSubview(self.highlightView)
            self.button.addSubview(self.titleView)

            self.addSubview(self.button)

            self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.button.highligthedChanged = { [weak self] highligthed in
                guard let strongSelf = self, let mediaPreviewView = strongSelf.mediaPreviewView else {
                    return
                }
                if strongSelf.isHighlightingEnabled && highligthed {
                    mediaPreviewView.alpha = 0.8
                } else {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                    transition.updateAlpha(layer: mediaPreviewView.layer, alpha: 1.0)
                }
            }
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        @objc private func pressed() {
            self.action?()
        }

        func update(component: DayComponent, availableSize: CGSize, environment: Environment<DayEnvironment>, transition: Transition) -> CGSize {
            let isFirstTime = self.action == nil

            self.action = component.action
            self.index = component.media?.message.index
            self.isHighlightingEnabled = component.isEnabled && component.media != nil && !component.isSelecting

            let diameter = min(availableSize.width, availableSize.height)
            let contentFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - diameter) / 2.0), y: floor((availableSize.height - diameter) / 2.0)), size: CGSize(width: diameter, height: diameter))

            let dayEnvironment = environment[DayEnvironment.self].value
            if component.media != nil {
                self.highlightView.image = dayEnvironment.imageCache.filledCircle(diameter: diameter, innerDiameter: nil, color: UIColor(white: 0.0, alpha: 0.2))
            } else {
                self.highlightView.image = nil
            }

            var animateMediaIn = false
            if self.currentMedia != component.media {
                self.currentMedia = component.media

                if let mediaPreviewView = self.mediaPreviewView {
                    self.mediaPreviewView = nil
                    mediaPreviewView.removeFromSuperview()
                } else {
                    animateMediaIn = !isFirstTime
                }

                if let media = component.media {
                    let mediaPreviewView = MediaPreviewView(context: component.context, message: media.message, media: media.media, imageCache: dayEnvironment.directImageCache)
                    mediaPreviewView.isUserInteractionEnabled = false
                    self.mediaPreviewView = mediaPreviewView
                    self.button.insertSubview(mediaPreviewView, belowSubview: self.highlightView)
                }
            }

            let titleColor: UIColor
            let titleFontSize: CGFloat
            let titleFontIsSemibold: Bool
            if component.media != nil {
                if component.theme.overallDarkAppearance {
                    titleColor = component.theme.list.itemPrimaryTextColor
                } else {
                    titleColor = component.theme.list.itemCheckColors.foregroundColor
                }
                titleFontSize = 17.0
                titleFontIsSemibold = true
            } else {
                titleFontSize = 17.0
                switch component.selection {
                case .middle, .edge:
                    titleFontIsSemibold = true
                default:
                    titleFontIsSemibold = component.isCurrent
                }

                if case .edge = component.selection {
                    if component.theme.overallDarkAppearance {
                        titleColor = component.theme.list.itemPrimaryTextColor
                    } else {
                        titleColor = component.theme.list.itemCheckColors.foregroundColor
                    }
                } else {
                    if component.isCurrent {
                        titleColor = component.theme.list.itemAccentColor
                    } else if component.isEnabled {
                        titleColor = component.theme.list.itemPrimaryTextColor
                    } else {
                        titleColor = component.theme.list.itemDisabledTextColor
                    }
                }
            }

            switch component.selection {
            case .edge:
                let selectionView: UIImageView
                if let current = self.selectionView {
                    selectionView = current
                } else {
                    selectionView = UIImageView()
                    self.selectionView = selectionView
                    self.button.insertSubview(selectionView, belowSubview: self.titleView)
                }
                selectionView.frame = contentFrame
                if self.mediaPreviewView != nil {
                    selectionView.image = dayEnvironment.imageCache.filledCircle(diameter: diameter, innerDiameter: diameter - 2.0 * 2.0, color: component.theme.list.itemCheckColors.fillColor)
                } else {
                    selectionView.image = dayEnvironment.imageCache.filledCircle(diameter: diameter, innerDiameter: nil, color: component.theme.list.itemCheckColors.fillColor)
                }
            case .middle, .none:
                if let selectionView = self.selectionView {
                    self.selectionView = nil
                    selectionView.removeFromSuperview()
                }
            }

            let contentScale: CGFloat
            switch component.selection {
            case .edge, .middle:
                contentScale = (contentFrame.width - 8.0) / contentFrame.width
            case .none:
                contentScale = 1.0
            }

            let titleImage = dayEnvironment.imageCache.text(fontSize: titleFontSize, isSemibold: titleFontIsSemibold, color: titleColor, string: component.title)
            if animateMediaIn {
                let previousTitleView = UIImageView(image: self.titleView.image)
                previousTitleView.frame = self.titleView.frame
                self.titleView.superview?.insertSubview(previousTitleView, aboveSubview: self.titleView)
                previousTitleView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousTitleView] _ in
                    previousTitleView?.removeFromSuperview()
                })
                self.titleView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.16)
            }
            self.titleView.image = titleImage
            let titleSize = titleImage.size

            transition.setFrame(view: self.highlightView, frame: CGRect(origin: CGPoint(x: contentFrame.midX - contentFrame.width * contentScale / 2.0, y: contentFrame.midY - contentFrame.width * contentScale / 2.0), size: CGSize(width: contentFrame.width * contentScale, height: contentFrame.height * contentScale)))

            self.titleView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: floor((availableSize.height - titleSize.height) / 2.0)), size: titleSize)

            self.button.frame = CGRect(origin: CGPoint(), size: availableSize)

            if let mediaPreviewView = self.mediaPreviewView {
                mediaPreviewView.frame = contentFrame
                mediaPreviewView.updateLayout(size: contentFrame.size, synchronousLoads: false)

                mediaPreviewView.layer.sublayerTransform = CATransform3DMakeScale(contentScale, contentScale, 1.0)

                if animateMediaIn {
                    mediaPreviewView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.highlightView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, environment: Environment<DayEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private final class MonthComponent: CombinedComponent {
    typealias EnvironmentType = DayEnvironment

    let context: AccountContext
    let model: MonthModel
    let foregroundColor: UIColor
    let strings: PresentationStrings
    let theme: PresentationTheme
    let dayAction: (Int32) -> Void
    let selectedDays: ClosedRange<Int32>?

    init(
        context: AccountContext,
        model: MonthModel,
        foregroundColor: UIColor,
        strings: PresentationStrings,
        theme: PresentationTheme,
        dayAction: @escaping (Int32) -> Void,
        selectedDays: ClosedRange<Int32>?
    ) {
        self.context = context
        self.model = model
        self.foregroundColor = foregroundColor
        self.strings = strings
        self.theme = theme
        self.dayAction = dayAction
        self.selectedDays = selectedDays
    }

    static func ==(lhs: MonthComponent, rhs: MonthComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.model != rhs.model {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.selectedDays != rhs.selectedDays {
            return false
        }
        return true
    }

    static var body: Body {
        let title = Child(Text.self)
        let weekdayTitles = ChildMap(environment: Empty.self, keyedBy: Int.self)
        let days = ChildMap(environment: DayEnvironment.self, keyedBy: Int.self)
        let selections = ChildMap(environment: Empty.self, keyedBy: Int.self)

        return { context in
            let sideInset: CGFloat = 14.0
            let titleWeekdaysSpacing: CGFloat = 18.0
            let weekdayDaySpacing: CGFloat = 14.0
            let weekdaySize: CGFloat = 46.0
            let weekdaySpacing: CGFloat = 6.0

            let usableWeekdayWidth = floor((context.availableSize.width - sideInset * 2.0 - weekdaySpacing * 6.0) / 7.0)
            let weekdayWidth = floor((context.availableSize.width - sideInset * 2.0) / 7.0)

            let title = title.update(
                component: Text(
                    text: "\(monthName(index: context.component.model.index - 1, strings: context.component.strings)) \(context.component.model.year)",
                    font: Font.semibold(17.0),
                    color: context.component.foregroundColor
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 100.0),
                transition: .immediate
            )

            let updatedWeekdayTitles = (0 ..< 7).map { index in
                return weekdayTitles[index].update(
                    component: AnyComponent(Text(
                        text: dayName(index: index, strings: context.component.strings),
                        font: Font.regular(10.0),
                        color: context.component.foregroundColor
                    )),
                    availableSize: CGSize(width: 100.0, height: 100.0),
                    transition: .immediate
                )
            }

            let updatedDays = (0 ..< context.component.model.numberOfDays).map { index -> _UpdatedChildComponent in
                let dayOfMonth = index + 1
                let isCurrent = context.component.model.currentYear == context.component.model.year && context.component.model.currentMonth == context.component.model.index && context.component.model.currentDayOfMonth == dayOfMonth
                var isEnabled = true
                if context.component.model.currentYear == context.component.model.year {
                    if context.component.model.currentMonth == context.component.model.index {
                        if dayOfMonth > context.component.model.currentDayOfMonth {
                            isEnabled = false
                        }
                    } else if context.component.model.index > context.component.model.currentMonth {
                        isEnabled = false
                    }
                } else if context.component.model.year > context.component.model.currentYear {
                    isEnabled = false
                }

                let dayTimestamp = Int32(context.component.model.firstDay.timeIntervalSince1970) + 24 * 60 * 60 * Int32(index)
                let dayAction = context.component.dayAction

                let daySelection: DayComponent.DaySelection
                if let selectedDays = context.component.selectedDays, selectedDays.contains(dayTimestamp) {
                    if selectedDays.lowerBound == dayTimestamp || selectedDays.upperBound == dayTimestamp {
                        daySelection = .edge
                    } else {
                        daySelection = .middle
                    }
                } else {
                    daySelection = .none
                }

                return days[index].update(
                    component: AnyComponent(DayComponent(
                        title: "\(dayOfMonth)",
                        isCurrent: isCurrent,
                        isEnabled: isEnabled,
                        theme: context.component.theme,
                        context: context.component.context,
                        media: context.component.model.mediaByDay[index],
                        selection: daySelection,
                        isSelecting: context.component.selectedDays != nil,
                        action: {
                            dayAction(dayTimestamp)
                        }
                    )),
                    environment: {
                        context.environment[DayEnvironment.self]
                    },
                    availableSize: CGSize(width: usableWeekdayWidth, height: weekdaySize),
                    transition: .immediate
                )
            }

            let titleFrame = CGRect(origin: CGPoint(x: floor((context.availableSize.width - title.size.width) / 2.0), y: 0.0), size: title.size)

            context.add(title
                .position(CGPoint(x: titleFrame.midX, y: titleFrame.midY))
            )

            let baseWeekdayTitleY = titleFrame.maxY + titleWeekdaysSpacing
            var maxWeekdayY = baseWeekdayTitleY

            for i in 0 ..< updatedWeekdayTitles.count {
                let weekdaySize = updatedWeekdayTitles[i].size
                let weekdayFrame = CGRect(origin: CGPoint(x: sideInset + CGFloat(i) * weekdayWidth + floor((weekdayWidth - weekdaySize.width) / 2.0), y: baseWeekdayTitleY), size: weekdaySize)
                maxWeekdayY = max(maxWeekdayY, weekdayFrame.maxY)
                context.add(updatedWeekdayTitles[i]
                    .position(CGPoint(x: weekdayFrame.midX, y: weekdayFrame.midY))
                )
            }

            let baseDayY = maxWeekdayY + weekdayDaySpacing
            var maxDayY = baseDayY

            struct LineSelection {
                var range: ClosedRange<Int>
                var leftTimestamp: Int32
                var rightTimestamp: Int32
            }

            var selectionsByLine: [Int: LineSelection] = [:]

            for i in 0 ..< updatedDays.count {
                let gridIndex = (context.component.model.firstDayWeekday - 1) + i
                let rowIndex = gridIndex % 7
                let lineIndex = gridIndex / 7

                if let selectedDays = context.component.selectedDays {
                    let dayTimestamp = Int32(context.component.model.firstDay.timeIntervalSince1970) + 24 * 60 * 60 * Int32(i)
                    if selectedDays.contains(dayTimestamp) {
                        if var currentSelection = selectionsByLine[lineIndex] {
                            if rowIndex < currentSelection.range.lowerBound {
                                currentSelection.range = rowIndex ... currentSelection.range.upperBound
                                currentSelection.leftTimestamp = dayTimestamp
                            } else {
                                currentSelection.range = currentSelection.range.lowerBound ... rowIndex
                                currentSelection.rightTimestamp = dayTimestamp
                            }
                            selectionsByLine[lineIndex] = currentSelection
                        } else {
                            selectionsByLine[lineIndex] = LineSelection(
                                range: rowIndex ... rowIndex,
                                leftTimestamp: dayTimestamp,
                                rightTimestamp: dayTimestamp
                            )
                        }
                    }
                }
            }

            if let selectedDays = context.component.selectedDays {
                for (lineIndex, selection) in selectionsByLine {
                    let dayEnvironment = context.environment[DayEnvironment.self].value

                    let dayItemSize = updatedDays[0].size
                    let deltaWidth = floor((weekdayWidth - dayItemSize.width) / 2.0)
                    let deltaHeight = floor((weekdaySize - dayItemSize.width) / 2.0)
                    let minX = sideInset + CGFloat(selection.range.lowerBound) * weekdayWidth + deltaWidth
                    let maxX = sideInset + CGFloat(selection.range.upperBound + 1) * weekdayWidth - deltaWidth
                    let minY = baseDayY + CGFloat(lineIndex) * (weekdaySize + weekdaySpacing) + deltaHeight
                    let maxY = minY + dayItemSize.width

                    let leftRadius: CGFloat
                    if selectedDays.lowerBound == selection.leftTimestamp {
                        leftRadius = dayItemSize.width
                    } else {
                        leftRadius = 10.0
                    }
                    let rightRadius: CGFloat
                    if selectedDays.upperBound == selection.rightTimestamp {
                        rightRadius = dayItemSize.width
                    } else {
                        rightRadius = 10.0
                    }

                    let monthSelectionColor = context.component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.1)

                    let selectionRect = CGRect(origin: CGPoint(x: minX, y: minY), size: CGSize(width: maxX - minX, height: maxY - minY))
                    let selection = selections[lineIndex].update(
                        component: AnyComponent(ImageComponent(image: dayEnvironment.imageCache.monthSelection(leftRadius: leftRadius, rightRadius: rightRadius, maxRadius: dayItemSize.width, color: monthSelectionColor))),
                        availableSize: selectionRect.size,
                        transition: .immediate
                    )
                    context.add(selection
                        .position(CGPoint(x: selectionRect.midX, y: selectionRect.midY))
                    )
                }
            }

            for i in 0 ..< updatedDays.count {
                let gridIndex = (context.component.model.firstDayWeekday - 1) + i
                let rowIndex = gridIndex % 7
                let lineIndex = gridIndex / 7

                let gridX = sideInset + CGFloat(rowIndex) * weekdayWidth
                let gridY = baseDayY + CGFloat(lineIndex) * (weekdaySize + weekdaySpacing)
                let dayItemSize = updatedDays[i].size
                let dayFrame = CGRect(origin: CGPoint(x: gridX + floor((weekdayWidth - dayItemSize.width) / 2.0), y: gridY + floor((weekdaySize - dayItemSize.height) / 2.0)), size: dayItemSize)
                maxDayY = max(maxDayY, gridY + weekdaySize)
                context.add(updatedDays[i]
                    .position(CGPoint(x: dayFrame.midX, y: dayFrame.midY))
                )
            }

            return CGSize(width: context.availableSize.width, height: maxDayY)
        }
    }
}

private struct DayMedia: Equatable {
    var message: EngineMessage
    var media: EngineMedia

    static func ==(lhs: DayMedia, rhs: DayMedia) -> Bool {
        if lhs.message.id != rhs.message.id {
            return false
        }
        return true
    }
}

private struct MonthModel: Equatable {
    var year: Int
    var index: Int
    var numberOfDays: Int
    var firstDay: Date
    var firstDayWeekday: Int
    var currentYear: Int
    var currentMonth: Int
    var currentDayOfMonth: Int
    var mediaByDay: [Int: DayMedia]

    init(
        year: Int,
        index: Int,
        numberOfDays: Int,
        firstDay: Date,
        firstDayWeekday: Int,
        currentYear: Int,
        currentMonth: Int,
        currentDayOfMonth: Int,
        mediaByDay: [Int: DayMedia]
    ) {
        self.year = year
        self.index = index
        self.numberOfDays = numberOfDays
        self.firstDay = firstDay
        self.firstDayWeekday = firstDayWeekday
        self.currentYear = currentYear
        self.currentMonth = currentMonth
        self.currentDayOfMonth = currentDayOfMonth
        self.mediaByDay = mediaByDay
    }
}

private func monthMetadata(calendar: Calendar, for baseDate: Date, currentYear: Int, currentMonth: Int, currentDayOfMonth: Int) -> MonthModel? {
    guard let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: baseDate)?.count, let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: baseDate)) else {
        return nil
    }

    let year = calendar.component(.year, from: firstDayOfMonth)
    let month = calendar.component(.month, from: firstDayOfMonth)
    let firstDayWeekday = calendar.component(.weekday, from: firstDayOfMonth)

    return MonthModel(
        year: year,
        index: month,
        numberOfDays: numberOfDaysInMonth,
        firstDay: firstDayOfMonth,
        firstDayWeekday: firstDayWeekday,
        currentYear: currentYear,
        currentMonth: currentMonth,
        currentDayOfMonth: currentDayOfMonth,
        mediaByDay: [:]
    )
}

public final class CalendarMessageScreen: ViewController {
    private final class Node: ViewControllerTracingNode, UIScrollViewDelegate {
        struct SelectionState {
            var dayRange: ClosedRange<Int32>?
        }

        private weak var controller: CalendarMessageScreen?
        private let context: AccountContext
        private let peerId: PeerId
        private let initialTimestamp: Int32
        private let navigateToOffset: (Int) -> Void
        private let previewDay: (MessageIndex, ASDisplayNode, CGRect, ContextGesture) -> Void

        private var presentationData: PresentationData
        private var scrollView: Scroller

        private let calendarSource: SparseMessageCalendar

        private var months: [MonthModel] = []
        private var monthViews: [Int: ComponentHostView<DayEnvironment>] = [:]
        private let contextGestureContainerNode: ContextControllerSourceNode

        private let dayEnvironment: DayEnvironment

        private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        private var scrollLayout: (width: CGFloat, contentHeight: CGFloat, frames: [Int: CGRect])?

        private var calendarState: SparseMessageCalendar.State?

        private var isLoadingMoreDisposable: Disposable?
        private var stateDisposable: Disposable?

        private weak var currentGestureDayView: DayComponent.View?

        private var selectionToolbarNode: ToolbarNode?
        private(set) var selectionState: SelectionState?

        private var ignoreContentOffset: Bool = false

        init(controller: CalendarMessageScreen, context: AccountContext, peerId: PeerId, calendarSource: SparseMessageCalendar, initialTimestamp: Int32, navigateToOffset: @escaping (Int) -> Void, previewDay: @escaping (MessageIndex, ASDisplayNode, CGRect, ContextGesture) -> Void) {
            self.controller = controller
            self.context = context
            self.peerId = peerId
            self.initialTimestamp = initialTimestamp
            self.calendarSource = calendarSource
            self.navigateToOffset = navigateToOffset
            self.previewDay = previewDay
            
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

            self.contextGestureContainerNode = ContextControllerSourceNode()

            self.scrollView = Scroller()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            if #available(iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            self.scrollView.layer.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
            self.scrollView.disablesInteractiveModalDismiss = true
            if self.presentationData.theme.overallDarkAppearance {
                self.scrollView.indicatorStyle = .white
            } else {
                self.scrollView.indicatorStyle = .black
            }

            self.dayEnvironment = DayEnvironment(imageCache: ImageCache(), directImageCache: DirectMediaImageCache(account: context.account))

            super.init()

            self.contextGestureContainerNode.shouldBegin = { [weak self] point in
                guard let strongSelf = self else {
                    return false
                }

                guard let result = strongSelf.contextGestureContainerNode.view.hitTest(point, with: nil) as? UIButton else {
                    return false
                }

                guard let dayView = result.superview as? DayComponent.View else {
                    return false
                }

                strongSelf.currentGestureDayView = dayView

                return true
            }

            self.contextGestureContainerNode.customActivationProgress = { [weak self] progress, update in
                guard let strongSelf = self, let currentGestureDayView = strongSelf.currentGestureDayView else {
                    return
                }
                let itemLayer = currentGestureDayView.layer

                let targetContentRect = CGRect(origin: CGPoint(), size: itemLayer.bounds.size)

                let scaleSide = itemLayer.bounds.width
                let minScale: CGFloat = max(0.7, (scaleSide - 15.0) / scaleSide)
                let currentScale = 1.0 * (1.0 - progress) + minScale * progress

                let originalCenterOffsetX: CGFloat = itemLayer.bounds.width / 2.0 - targetContentRect.midX
                let scaledCenterOffsetX: CGFloat = originalCenterOffsetX * currentScale

                let originalCenterOffsetY: CGFloat = itemLayer.bounds.height / 2.0 - targetContentRect.midY
                let scaledCenterOffsetY: CGFloat = originalCenterOffsetY * currentScale

                let scaleMidX: CGFloat = scaledCenterOffsetX - originalCenterOffsetX
                let scaleMidY: CGFloat = scaledCenterOffsetY - originalCenterOffsetY

                switch update {
                case .update:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    itemLayer.sublayerTransform = sublayerTransform
                case .begin:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    itemLayer.sublayerTransform = sublayerTransform
                case .ended:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    let previousTransform = itemLayer.sublayerTransform
                    itemLayer.sublayerTransform = sublayerTransform

                    itemLayer.animate(from: NSValue(caTransform3D: previousTransform), to: NSValue(caTransform3D: sublayerTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
                }
            }

            self.contextGestureContainerNode.activated = { [weak self] gesture, _ in
                guard let strongSelf = self, let currentGestureDayView = strongSelf.currentGestureDayView else {
                    return
                }
                strongSelf.currentGestureDayView = nil

                currentGestureDayView.isUserInteractionEnabled = false
                currentGestureDayView.isUserInteractionEnabled = true

                if let index = currentGestureDayView.index {
                    strongSelf.previewDay(index, strongSelf, currentGestureDayView.convert(currentGestureDayView.bounds, to: strongSelf.view), gesture)
                }
            }

            let calendar = Calendar(identifier: .gregorian)

            let baseDate = Date()
            let currentYear = calendar.component(.year, from: baseDate)
            let currentMonth = calendar.component(.month, from: baseDate)
            let currentDayOfMonth = calendar.component(.day, from: baseDate)

            for i in 0 ..< 12 * 20 {
                guard let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: baseDate)) else {
                    break
                }
                guard let monthBaseDate = calendar.date(byAdding: .month, value: -i, to: firstDayOfMonth) else {
                    break
                }

                guard let monthModel = monthMetadata(calendar: calendar, for: monthBaseDate, currentYear: currentYear, currentMonth: currentMonth, currentDayOfMonth: currentDayOfMonth) else {
                    break
                }

                let firstDayTimestamp = Int32(monthModel.firstDay.timeIntervalSince1970)
                let lastDayTimestamp = firstDayTimestamp + 24 * 60 * 60 * Int32(monthModel.numberOfDays)

                if let minTimestamp = calendarSource.minTimestamp, minTimestamp > lastDayTimestamp {
                    break
                }

                if monthModel.year < 2013 {
                    break
                }
                if monthModel.year == 2013 {
                    if monthModel.index < 8 {
                        break
                    }
                }

                self.months.append(monthModel)
            }

            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor

            self.scrollView.delegate = self
            self.addSubnode(self.contextGestureContainerNode)
            self.contextGestureContainerNode.view.addSubview(self.scrollView)

            self.isLoadingMoreDisposable = (self.calendarSource.isLoadingMore
            |> distinctUntilChanged
            |> filter { !$0 }
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.calendarSource.loadMore()
            })

            self.stateDisposable = (self.calendarSource.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.calendarState = state
                strongSelf.reloadMediaInfo()
            })
        }

        deinit {
            self.isLoadingMoreDisposable?.dispose()
            self.stateDisposable?.dispose()
        }

        func toggleSelectionMode() {
            if self.selectionState == nil {
                self.selectionState = SelectionState(dayRange: nil)
            } else {
                self.selectionState = nil
            }

            self.contextGestureContainerNode.isGestureEnabled = self.selectionState == nil

            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.5, curve: .spring))
            }
        }

        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let isFirstLayout = self.validLayout == nil
            self.validLayout = (layout, navigationHeight)

            var tabBarHeight: CGFloat
            var options: ContainerViewLayoutInsetOptions = []
            if layout.metrics.widthClass == .regular {
                options.insert(.input)
            }
            let bottomInset: CGFloat = layout.insets(options: options).bottom
            if !layout.safeInsets.left.isZero {
                tabBarHeight = 34.0 + bottomInset
            } else {
                tabBarHeight = 49.0 + bottomInset
            }

            let tabBarFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - tabBarHeight), size: CGSize(width: layout.size.width, height: tabBarHeight))

            if let _ = self.selectionState {
                let selectionToolbarNode: ToolbarNode
                if let currrent = self.selectionToolbarNode {
                    selectionToolbarNode = currrent

                    transition.updateFrame(node: selectionToolbarNode, frame: tabBarFrame)
                    selectionToolbarNode.updateLayout(size: tabBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: layout.additionalInsets, bottomInset: bottomInset, toolbar: Toolbar(leftAction: nil, rightAction: nil, middleAction: ToolbarAction(title: self.presentationData.strings.DialogList_ClearHistoryConfirmation, isEnabled: self.selectionState?.dayRange != nil, color: .custom(self.presentationData.theme.list.itemDestructiveColor))), transition: transition)
                } else {
                    selectionToolbarNode = ToolbarNode(
                        theme: TabBarControllerTheme(
                        rootControllerTheme: self.presentationData.theme),
                        displaySeparator: true,
                        left: {
                        },
                        right: {
                        },
                        middle: { [weak self] in
                            self?.selectionToolbarActionSelected()
                        }
                    )
                    selectionToolbarNode.frame = tabBarFrame
                    selectionToolbarNode.updateLayout(size: tabBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: layout.additionalInsets, bottomInset: bottomInset, toolbar: Toolbar(leftAction: nil, rightAction: nil, middleAction: ToolbarAction(title: self.presentationData.strings.DialogList_ClearHistoryConfirmation, isEnabled: self.selectionState?.dayRange != nil, color: .custom(self.presentationData.theme.list.itemDestructiveColor))), transition: .immediate)
                    self.addSubnode(selectionToolbarNode)
                    self.selectionToolbarNode = selectionToolbarNode
                    transition.animatePositionAdditive(node: selectionToolbarNode, offset: CGPoint(x: 0.0, y: tabBarFrame.height))
                }
            } else if let selectionToolbarNode = self.selectionToolbarNode {
                self.selectionToolbarNode = nil
                transition.updatePosition(node: selectionToolbarNode, position: CGPoint(x: selectionToolbarNode.position.x, y: selectionToolbarNode.position.y + tabBarFrame.height), completion: { [weak selectionToolbarNode] _ in
                    selectionToolbarNode?.removeFromSupernode()
                })
            }

            let _ = self.updateScrollLayoutIfNeeded()

            let previousInset = self.scrollView.contentInset.top
            let updatedInset = self.selectionToolbarNode?.bounds.height ?? 0.0
            if previousInset != updatedInset {
                let delta = updatedInset - previousInset
                self.ignoreContentOffset = true
                let contentOffset = self.scrollView.contentOffset
                self.scrollView.contentInset = UIEdgeInsets(top: updatedInset, left: 0.0, bottom: 0.0, right: 0.0)
                var updatedContentOffset = CGPoint(x: contentOffset.x, y: contentOffset.y - delta)
                if updatedContentOffset.y > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                    updatedContentOffset.y = self.scrollView.contentSize.height - self.scrollView.bounds.height
                }
                if updatedContentOffset.y < -self.scrollView.contentInset.top {
                    updatedContentOffset.y = -self.scrollView.contentInset.top
                }
                self.scrollView.contentOffset = updatedContentOffset
                self.ignoreContentOffset = false
                transition.animateOffsetAdditive(layer: self.scrollView.layer, offset: contentOffset.y - updatedContentOffset.y)
            }

            if isFirstLayout {
                let initialDate = Date(timeIntervalSince1970: TimeInterval(self.initialTimestamp))
                var initialMonthIndex: Int?

                if self.months.count > 1 {
                    for i in 0 ..< self.months.count - 1 {
                        if initialDate >= self.months[i].firstDay {
                            initialMonthIndex = i
                            break
                        }
                    }
                }

                if let initialMonthIndex = initialMonthIndex, let frame = self.scrollLayout?.frames[initialMonthIndex] {
                    var contentOffset = floor(frame.midY - self.scrollView.bounds.height / 2.0)
                    if contentOffset < 0 {
                        contentOffset = 0
                    }
                    if contentOffset > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                        contentOffset = self.scrollView.contentSize.height - self.scrollView.bounds.height
                    }
                    self.ignoreContentOffset = true
                    self.scrollView.setContentOffset(CGPoint(x: 0.0, y: contentOffset), animated: false)
                    self.ignoreContentOffset = false
                }
            } else {

            }

            updateMonthViews()
        }

        private func selectionToolbarActionSelected() {
            guard let selectionState = self.selectionState, let dayRange = selectionState.dayRange else {
                return
            }
            var selectedCount = 0
            var minTimestamp: Int32?
            var maxTimestamp: Int32?
            for i in 0 ..< self.months.count {
                let firstDayTimestamp = Int32(self.months[i].firstDay.timeIntervalSince1970)

                for day in 0 ..< self.months[i].numberOfDays {
                    let dayTimestamp = firstDayTimestamp + 24 * 60 * 60 * Int32(day)
                    let nextDayTimestamp = dayTimestamp + 24 * 60 * 60

                    let minDayTimestamp = dayTimestamp - 24 * 60 * 60
                    let maxDayTimestamp = nextDayTimestamp - 24 * 60 * 60

                    if dayRange.contains(dayTimestamp) {
                        if let currentMinTimestamp = minTimestamp {
                            minTimestamp = min(minDayTimestamp, currentMinTimestamp)
                        } else {
                            minTimestamp = minDayTimestamp
                        }
                        if let currentMaxTimestamp = maxTimestamp {
                            maxTimestamp = max(maxDayTimestamp, currentMaxTimestamp)
                        } else {
                            maxTimestamp = maxDayTimestamp
                        }
                        selectedCount += 1
                    }
                }
            }

            guard let minTimestampValue = minTimestamp, let maxTimestampValue = maxTimestamp else {
                return
            }

            if selectedCount == 0 {
                return
            }

            enum ClearType {
                case savedMessages
                case secretChat
                case group
                case channel
                case user
            }

            struct ClearInfo {
                var canClearForMyself: ClearType?
                var canClearForEveryone: ClearType?
                var mainPeer: Peer
            }

            let peerId = self.peerId
            if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat {
            } else {
                return
            }
            let _ = (self.context.account.postbox.transaction { transaction -> ClearInfo? in
                guard let chatPeer = transaction.getPeer(peerId) else {
                    return nil
                }

                let canClearForMyself: ClearType?
                let canClearForEveryone: ClearType?

                if peerId == self.context.account.peerId {
                    canClearForMyself = .savedMessages
                    canClearForEveryone = nil
                } else if chatPeer is TelegramSecretChat {
                    canClearForMyself = .secretChat
                    canClearForEveryone = nil
                } else if let group = chatPeer as? TelegramGroup {
                    switch group.role {
                    case .creator:
                        canClearForMyself = .group
                        canClearForEveryone = nil
                    case .admin, .member:
                        canClearForMyself = .group
                        canClearForEveryone = nil
                    }
                } else if let channel = chatPeer as? TelegramChannel {
                    if channel.hasPermission(.deleteAllMessages) {
                        if case .group = channel.info {
                            canClearForEveryone = .group
                        } else {
                            canClearForEveryone = .channel
                        }
                    } else {
                        canClearForEveryone = nil
                    }
                    canClearForMyself = nil
                } else {
                    canClearForMyself = .user

                    if let user = chatPeer as? TelegramUser, user.botInfo != nil {
                        canClearForEveryone = nil
                    } else {
                        canClearForEveryone = .user
                    }
                }

                return ClearInfo(
                    canClearForMyself: canClearForMyself,
                    canClearForEveryone: canClearForEveryone,
                    mainPeer: chatPeer
                )
            }
            |> deliverOnMainQueue).start(next: { [weak self] info in
                guard let strongSelf = self, let info = info else {
                    return
                }

                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                var items: [ActionSheetItem] = []

                let beginClear: (InteractiveHistoryClearingType) -> Void = { type in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = strongSelf.calendarSource.removeMessagesInRange(minTimestamp: minTimestampValue, maxTimestamp: maxTimestampValue, type: type, completion: {
                    })
                }

                if let _ = info.canClearForMyself ?? info.canClearForEveryone {
                    //TODO:localize
                    items.append(ActionSheetTextItem(title: "Are you sure you want to delete all messages for the \(selectedCount) selected days?"))

                    if let canClearForEveryone = info.canClearForEveryone {
                        let text: String
                        let confirmationText: String
                        switch canClearForEveryone {
                        case .user:
                            text = strongSelf.presentationData.strings.ChatList_DeleteForEveryone(EnginePeer(info.mainPeer).compactDisplayTitle).string
                            confirmationText = strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationText
                        default:
                            text = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                            confirmationText = strongSelf.presentationData.strings.ChatList_DeleteForAllMembersConfirmationText
                        }
                        let _ = confirmationText
                        items.append(ActionSheetButtonItem(title: text, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            beginClear(.forEveryone)

                            /*guard let strongSelf = self else {
                                return
                            }

                            strongSelf.controller?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationTitle, text: confirmationText, actions: [
                                TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                }),
                                TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationAction, action: {
                                    beginClear(.forEveryone)
                                })
                            ], parseMarkdown: true), in: .window(.root))*/
                        }))
                    }
                    if let canClearForMyself = info.canClearForMyself {
                        let text: String
                        switch canClearForMyself {
                        case .savedMessages, .secretChat:
                            text = strongSelf.presentationData.strings.Conversation_DeleteManyMessages
                        default:
                            text = strongSelf.presentationData.strings.ChatList_DeleteForCurrentUser
                        }
                        items.append(ActionSheetButtonItem(title: text, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            beginClear(.forLocalPeer)
                        }))
                    }
                }

                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])

                strongSelf.controller?.present(actionSheet, in: .window(.root))
            })

            self.controller?.toggleSelectPressed()
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.contextGestureContainerNode.cancelGesture()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreContentOffset {
                if let indicator = scrollView.value(forKey: "_verticalScrollIndicator") as? UIView {
                    indicator.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
                }

                self.updateMonthViews()
            }
        }

        func updateScrollLayoutIfNeeded() -> Bool {
            guard let (layout, navigationHeight) = self.validLayout else {
                return false
            }
            if self.scrollLayout?.width == layout.size.width {
                return false
            }

            var contentHeight: CGFloat = layout.intrinsicInsets.bottom
            var frames: [Int: CGRect] = [:]

            let measureView = ComponentHostView<DayEnvironment>()
            for i in 0 ..< self.months.count {
                let monthSize = measureView.update(
                    transition: .immediate,
                    component: AnyComponent(MonthComponent(
                        context: self.context,
                        model: self.months[i],
                        foregroundColor: .black,
                        strings: self.presentationData.strings,
                        theme: self.presentationData.theme,
                        dayAction: { _ in
                        },
                        selectedDays: nil
                    )),
                    environment: {
                        self.dayEnvironment
                    },
                    containerSize: CGSize(width: layout.size.width, height: 10000.0
                ))
                let monthFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: monthSize)
                contentHeight += monthSize.height
                if i != self.months.count {
                    contentHeight += 16.0
                }
                frames[i] = monthFrame
            }

            self.scrollLayout = (layout.size.width, contentHeight, frames)

            self.contextGestureContainerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationHeight))
            self.scrollView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: layout.size.height - navigationHeight))
            self.scrollView.contentSize = CGSize(width: layout.size.width, height: contentHeight)
            self.scrollView.scrollIndicatorInsets = UIEdgeInsets(top: max(layout.intrinsicInsets.bottom, self.scrollView.contentInset.top), left: 0.0, bottom: 0.0, right: layout.size.width - 3.0 - 6.0)

            return true
        }

        func updateMonthViews() {
            guard let (width, _, frames) = self.scrollLayout else {
                return
            }

            let visibleRect = self.scrollView.bounds.insetBy(dx: 0.0, dy: -200.0)
            var validMonths = Set<Int>()

            for i in 0 ..< self.months.count {
                guard let monthFrame = frames[i] else {
                    continue
                }
                if !visibleRect.intersects(monthFrame) {
                    continue
                }
                validMonths.insert(i)

                let monthView: ComponentHostView<DayEnvironment>
                if let current = self.monthViews[i] {
                    monthView = current
                } else {
                    monthView = ComponentHostView()
                    monthView.layer.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
                    self.monthViews[i] = monthView
                    self.scrollView.addSubview(monthView)
                }
                let _ = monthView.update(
                    transition: .immediate,
                    component: AnyComponent(MonthComponent(
                        context: self.context,
                        model: self.months[i],
                        foregroundColor: self.presentationData.theme.list.itemPrimaryTextColor,
                        strings: self.presentationData.strings,
                        theme: self.presentationData.theme,
                        dayAction: { [weak self] timestamp in
                            guard let strongSelf = self else {
                                return
                            }
                            if var selectionState = strongSelf.selectionState {
                                if let dayRange = selectionState.dayRange {
                                    if dayRange.lowerBound == dayRange.upperBound {
                                        if timestamp < dayRange.lowerBound {
                                            selectionState.dayRange = timestamp ... dayRange.upperBound
                                        } else {
                                            selectionState.dayRange = dayRange.lowerBound ... timestamp
                                        }
                                    } else {
                                        selectionState.dayRange = timestamp ... timestamp
                                    }
                                } else {
                                    selectionState.dayRange = timestamp ... timestamp
                                }
                                strongSelf.selectionState = selectionState

                                strongSelf.updateSelectionState()
                            } else if let calendarState = strongSelf.calendarState {
                                outer: for month in strongSelf.months {
                                    let firstDayTimestamp = Int32(month.firstDay.timeIntervalSince1970)

                                    for day in 0 ..< month.numberOfDays {
                                        let dayTimestamp = firstDayTimestamp + 24 * 60 * 60 * Int32(day)
                                        if dayTimestamp == timestamp {
                                            if month.mediaByDay[day] != nil {
                                                var offset = 0
                                                for key in calendarState.messagesByDay.keys.sorted(by: { $0 > $1 }) {
                                                    if key == dayTimestamp {
                                                        break
                                                    } else if let item = calendarState.messagesByDay[key] {
                                                        offset += item.count
                                                    }
                                                }
                                                strongSelf.navigateToOffset(offset)
                                            }

                                            break outer
                                        }
                                    }
                                }
                            }
                        },
                        selectedDays: self.selectionState?.dayRange
                    )),
                    environment: {
                        self.dayEnvironment
                    },
                    containerSize: CGSize(width: width, height: 10000.0
                ))
                monthView.frame = monthFrame
            }

            var removeMonths: [Int] = []
            for (index, view) in self.monthViews {
                if !validMonths.contains(index) {
                    view.removeFromSuperview()
                    removeMonths.append(index)
                }
            }
            for index in removeMonths {
                self.monthViews.removeValue(forKey: index)
            }
        }

        private func updateSelectionState() {
            //TODO:localize
            var title = "Calendar"
            if let selectionState = self.selectionState, let dayRange = selectionState.dayRange {
                var selectedCount = 0
                for i in 0 ..< self.months.count {
                    let firstDayTimestamp = Int32(self.months[i].firstDay.timeIntervalSince1970)

                    for day in 0 ..< self.months[i].numberOfDays {
                        let dayTimestamp = firstDayTimestamp + 24 * 60 * 60 * Int32(day)
                        if dayRange.contains(dayTimestamp) {
                            selectedCount += 1
                        }
                    }
                }

                if selectedCount != 0 {
                    if selectedCount == 1 {
                        title = "1 day selected"
                    } else {
                        title = "\(selectedCount) days selected"
                    }
                }
            }

            self.controller?.navigationItem.title = title

            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.5, curve: .spring))
            }
        }

        private func reloadMediaInfo() {
            guard let calendarState = self.calendarState else {
                return
            }
            var messageMap: [Message] = []
            for (_, entry) in calendarState.messagesByDay {
                messageMap.append(entry.message)
            }

            var updatedMedia: [Int: [Int: DayMedia]] = [:]
            for i in 0 ..< self.months.count {
                if updatedMedia[i] == nil {
                    updatedMedia[i] = [:]
                }

                let firstDayTimestamp = Int32(self.months[i].firstDay.timeIntervalSince1970)

                for day in 0 ..< self.months[i].numberOfDays {
                    let dayTimestamp = firstDayTimestamp + 24 * 60 * 60 * Int32(day)
                    let nextDayTimestamp = dayTimestamp + 24 * 60 * 60

                    for message in messageMap {
                        if message.timestamp >= dayTimestamp && message.timestamp < nextDayTimestamp {
                            mediaLoop: for media in message.media {
                                switch media {
                                case _ as TelegramMediaImage, _ as TelegramMediaFile:
                                    updatedMedia[i]![day] = DayMedia(message: EngineMessage(message), media: EngineMedia(media))
                                    break mediaLoop
                                default:
                                    break
                                }
                            }

                            break
                        }
                    }
                }
            }
            for (monthIndex, mediaByDay) in updatedMedia {
                self.months[monthIndex].mediaByDay = mediaByDay
            }

            self.updateMonthViews()
        }
    }

    private var node: Node {
        return self.displayNode as! Node
    }

    private let context: AccountContext
    private let peerId: PeerId
    private let calendarSource: SparseMessageCalendar
    private let initialTimestamp: Int32
    private let navigateToDay: (CalendarMessageScreen, Int) -> Void
    private let previewDay: (MessageIndex, ASDisplayNode, CGRect, ContextGesture) -> Void

    private var presentationData: PresentationData

    public init(context: AccountContext, peerId: PeerId, calendarSource: SparseMessageCalendar, initialTimestamp: Int32, navigateToDay: @escaping (CalendarMessageScreen, Int) -> Void, previewDay: @escaping (MessageIndex, ASDisplayNode, CGRect, ContextGesture) -> Void) {
        self.context = context
        self.peerId = peerId
        self.calendarSource = calendarSource
        self.initialTimestamp = initialTimestamp
        self.navigateToDay = navigateToDay
        self.previewDay = previewDay

        self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.navigationPresentation = .modal

        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(dismissPressed)), animated: false)
        //TODO:localize
        self.navigationItem.setTitle("Calendar", animated: false)

        /*if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat {
            self.navigationItem.setRightBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Select, style: .plain, target: self, action: #selector(self.toggleSelectPressed)), animated: false)
        }*/
    }

    required public init(coder aDecoder: NSCoder) {
        preconditionFailure()
    }

    @objc private func dismissPressed() {
        self.dismiss()
    }

    @objc fileprivate func toggleSelectPressed() {
        self.node.toggleSelectionMode()

        if self.node.selectionState != nil {
            self.navigationItem.setRightBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.toggleSelectPressed)), animated: true)
        } else {
            self.navigationItem.setRightBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Select, style: .plain, target: self, action: #selector(self.toggleSelectPressed)), animated: true)
        }
    }

    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self, context: self.context, peerId: self.peerId, calendarSource: self.calendarSource, initialTimestamp: self.initialTimestamp, navigateToOffset: { [weak self] index in
            guard let strongSelf = self else {
                return
            }
            strongSelf.navigateToDay(strongSelf, index)
        }, previewDay: self.previewDay)

        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.node.containerLayoutUpdated(layout: layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}