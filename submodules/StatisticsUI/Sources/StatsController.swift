import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import MapKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListUI
import PresentationDataUtils
import AccountContext
import PresentationDataUtils
import AppBundle
import GraphUI

private final class StatsControllerArguments {
    let context: AccountContext
    let loadDetailedGraph: (ChannelStatsGraph, Int64) -> Signal<ChannelStatsGraph?, NoError>
    let openMessage: (MessageId) -> Void
    
    init(context: AccountContext, loadDetailedGraph: @escaping (ChannelStatsGraph, Int64) -> Signal<ChannelStatsGraph?, NoError>, openMessage: @escaping (MessageId) -> Void) {
        self.context = context
        self.loadDetailedGraph = loadDetailedGraph
        self.openMessage = openMessage
    }
}

private enum StatsSection: Int32 {
    case overview
    case growth
    case followers
    case notifications
    case viewsByHour
    case viewsBySource
    case followersBySource
    case languages
    case postInteractions
    case recentPosts
    case instantPageInteractions
}

private enum StatsEntry: ItemListNodeEntry {
    case overviewHeader(PresentationTheme, String, String)
    case overview(PresentationTheme, ChannelStats)
    
    case growthTitle(PresentationTheme, String)
    case growthGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, ChannelStatsGraph, ChartType)
    
    case followersTitle(PresentationTheme, String)
    case followersGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, ChannelStatsGraph, ChartType)
     
    case notificationsTitle(PresentationTheme, String)
    case notificationsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, ChannelStatsGraph, ChartType)
    
    case viewsByHourTitle(PresentationTheme, String)
    case viewsByHourGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, ChannelStatsGraph, ChartType)
        
    case viewsBySourceTitle(PresentationTheme, String)
    case viewsBySourceGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, ChannelStatsGraph, ChartType)
    
    case followersBySourceTitle(PresentationTheme, String)
    case followersBySourceGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, ChannelStatsGraph, ChartType)
    
    case languagesTitle(PresentationTheme, String)
    case languagesGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, ChannelStatsGraph, ChartType)
    
    case postInteractionsTitle(PresentationTheme, String)
    case postInteractionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, ChannelStatsGraph, ChartType)
    
    case postsTitle(PresentationTheme, String)
    case post(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Message, ChannelStatsMessageInteractions)
    
    case instantPageInteractionsTitle(PresentationTheme, String)
    case instantPageInteractionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, ChannelStatsGraph, ChartType)
    
    var section: ItemListSectionId {
        switch self {
            case .overviewHeader, .overview:
                return StatsSection.overview.rawValue
            case .growthTitle, .growthGraph:
                return StatsSection.growth.rawValue
            case .followersTitle, .followersGraph:
                return StatsSection.followers.rawValue
            case .notificationsTitle, .notificationsGraph:
                return StatsSection.notifications.rawValue
            case .viewsByHourTitle, .viewsByHourGraph:
                return StatsSection.viewsByHour.rawValue
            case .viewsBySourceTitle, .viewsBySourceGraph:
                return StatsSection.viewsBySource.rawValue
            case .followersBySourceTitle, .followersBySourceGraph:
                return StatsSection.followersBySource.rawValue
            case .languagesTitle, .languagesGraph:
                return StatsSection.languages.rawValue
            case .postInteractionsTitle, .postInteractionsGraph:
                return StatsSection.postInteractions.rawValue
            case .postsTitle, .post:
                return StatsSection.recentPosts.rawValue
            case .instantPageInteractionsTitle, .instantPageInteractionsGraph:
                return StatsSection.instantPageInteractions.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .overviewHeader:
                return 0
            case .overview:
                return 1
            case .growthTitle:
                return 2
            case .growthGraph:
                return 3
            case .followersTitle:
                return 4
            case .followersGraph:
                return 5
            case .notificationsTitle:
                return 6
            case .notificationsGraph:
                return 7
            case .viewsByHourTitle:
                return 8
            case .viewsByHourGraph:
                return 9
            case .viewsBySourceTitle:
                return 10
            case .viewsBySourceGraph:
                return 11
            case .followersBySourceTitle:
                return 12
            case .followersBySourceGraph:
                return 13
            case .languagesTitle:
                return 14
            case .languagesGraph:
                return 15
            case .postInteractionsTitle:
                return 16
            case .postInteractionsGraph:
                return 17
            case .postsTitle:
                return 18
            case let .post(index, _, _, _, _, _):
                return 19 + index
            case .instantPageInteractionsTitle:
                return 1000
            case .instantPageInteractionsGraph:
                return 1001
        }
    }
    
    static func ==(lhs: StatsEntry, rhs: StatsEntry) -> Bool {
        switch lhs {
            case let .overviewHeader(lhsTheme, lhsText, lhsDates):
                if case let .overviewHeader(rhsTheme, rhsText, rhsDates) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsDates == rhsDates {
                    return true
                } else {
                    return false
                }
            case let .overview(lhsTheme, lhsStats):
                if case let .overview(rhsTheme, rhsStats) = rhs, lhsTheme === rhsTheme, lhsStats == rhsStats {
                    return true
                } else {
                    return false
                }
            case let .growthTitle(lhsTheme, lhsText):
                if case let .growthTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .growthGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .growthGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .followersTitle(lhsTheme, lhsText):
                if case let .followersTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .followersGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .followersGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .notificationsTitle(lhsTheme, lhsText):
                  if case let .notificationsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                      return true
                  } else {
                      return false
                  }
            case let .notificationsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .notificationsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .viewsByHourTitle(lhsTheme, lhsText):
                if case let .viewsByHourTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .viewsByHourGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .viewsByHourGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .viewsBySourceTitle(lhsTheme, lhsText):
                if case let .viewsBySourceTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .viewsBySourceGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .viewsBySourceGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .followersBySourceTitle(lhsTheme, lhsText):
                if case let .followersBySourceTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .followersBySourceGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .followersBySourceGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .languagesTitle(lhsTheme, lhsText):
                if case let .languagesTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .languagesGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .languagesGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .postInteractionsTitle(lhsTheme, lhsText):
                if case let .postInteractionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .postInteractionsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .postInteractionsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .postsTitle(lhsTheme, lhsText):
                if case let .postsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .post(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsMessage, lhsInteractions):
                if case let .post(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsMessage, rhsInteractions) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsInteractions == rhsInteractions {
                    return true
                } else {
                    return false
                }
            case let .instantPageInteractionsTitle(lhsTheme, lhsText):
                if case let .instantPageInteractionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .instantPageInteractionsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .instantPageInteractionsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: StatsEntry, rhs: StatsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! StatsControllerArguments
        switch self {
            case let .overviewHeader(_, text, dates):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, accessoryText: ItemListSectionHeaderAccessoryText(value: dates, color: .generic), sectionId: self.section)
            case let .growthTitle(_, text),
                 let .followersTitle(_, text),
                 let .notificationsTitle(_, text),
                 let .viewsByHourTitle(_, text),
                 let .viewsBySourceTitle(_, text),
                 let .followersBySourceTitle(_, text),
                 let .languagesTitle(_, text),
                 let .postInteractionsTitle(_, text),
                 let .postsTitle(_, text),
                 let .instantPageInteractionsTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .overview(_, stats):
                return StatsOverviewItem(presentationData: presentationData, stats: stats, sectionId: self.section, style: .blocks)
            case let .growthGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, sectionId: self.section, style: .blocks)
            case let .followersGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, sectionId: self.section, style: .blocks)
            case let .notificationsGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, sectionId: self.section, style: .blocks)
            case let .viewsByHourGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, sectionId: self.section, style: .blocks)
            case let .viewsBySourceGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, sectionId: self.section, style: .blocks)
            case let .followersBySourceGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, sectionId: self.section, style: .blocks)
            case let .languagesGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, sectionId: self.section, style: .blocks)
            case let .postInteractionsGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, getDetailsData: { date, completion in
                    let _ = arguments.loadDetailedGraph(graph, Int64(date.timeIntervalSince1970) * 1000).start(next: { graph in
                        if let graph = graph, case let .Loaded(_, data) = graph {
                            completion(data)
                        }
                    })
                }, sectionId: self.section, style: .blocks)
            case let .instantPageInteractionsGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, getDetailsData: { date, completion in
                    let _ = arguments.loadDetailedGraph(graph, Int64(date.timeIntervalSince1970) * 1000).start(next: { graph in
                        if let graph = graph, case let .Loaded(_, data) = graph {
                            completion(data)
                        }
                    })
                }, sectionId: self.section, style: .blocks)
            case let .post(_, _, _, _, message, interactions):
                return StatsMessageItem(context: arguments.context, presentationData: presentationData, message: message, views: interactions.views, forwards: interactions.forwards, sectionId: self.section, style: .blocks, action: {
                    arguments.openMessage(message.id)
                })
        }
    }
}

private func statsControllerEntries(data: ChannelStats?, messages: [Message]?, interactions: [MessageId: ChannelStatsMessageInteractions]?, presentationData: PresentationData) -> [StatsEntry] {
    var entries: [StatsEntry] = []
    
    if let data = data {
        let minDate = stringForDate(timestamp: data.period.minDate, strings: presentationData.strings)
        let maxDate = stringForDate(timestamp: data.period.maxDate, strings: presentationData.strings)
        
        entries.append(.overviewHeader(presentationData.theme, presentationData.strings.Stats_Overview, "\(minDate) – \(maxDate)"))
        entries.append(.overview(presentationData.theme, data))
    
        if !data.growthGraph.isEmpty {
            entries.append(.growthTitle(presentationData.theme, presentationData.strings.Stats_GrowthTitle))
            entries.append(.growthGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.growthGraph, .lines))
        }
        
        if !data.followersGraph.isEmpty {
            entries.append(.followersTitle(presentationData.theme, presentationData.strings.Stats_FollowersTitle))
            entries.append(.followersGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.followersGraph, .lines))
        }

        if !data.muteGraph.isEmpty {
            entries.append(.notificationsTitle(presentationData.theme, presentationData.strings.Stats_NotificationsTitle))
            entries.append(.notificationsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.muteGraph, .lines))
        }
        
        if !data.topHoursGraph.isEmpty {
            entries.append(.viewsByHourTitle(presentationData.theme, presentationData.strings.Stats_ViewsByHoursTitle))
            entries.append(.viewsByHourGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.topHoursGraph, .hourlyStep))
        }

        if !data.viewsBySourceGraph.isEmpty {
            entries.append(.viewsBySourceTitle(presentationData.theme, presentationData.strings.Stats_ViewsBySourceTitle))
            entries.append(.viewsBySourceGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.viewsBySourceGraph, .bars))
        }

        if !data.newFollowersBySourceGraph.isEmpty {
            entries.append(.followersBySourceTitle(presentationData.theme, presentationData.strings.Stats_FollowersBySourceTitle))
            entries.append(.followersBySourceGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.newFollowersBySourceGraph, .bars))
        }

        if !data.languagesGraph.isEmpty {
            entries.append(.languagesTitle(presentationData.theme, presentationData.strings.Stats_LanguagesTitle))
            entries.append(.languagesGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.languagesGraph, .pie))
        }

        if !data.interactionsGraph.isEmpty {
            entries.append(.postInteractionsTitle(presentationData.theme, presentationData.strings.Stats_InteractionsTitle))
            entries.append(.postInteractionsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.interactionsGraph, .twoAxisStep))
        }

        if let messages = messages, !messages.isEmpty, let interactions = interactions, !interactions.isEmpty {
            entries.append(.postsTitle(presentationData.theme, presentationData.strings.Stats_PostsTitle))
            var index: Int32 = 0
            for message in messages {
                if let interactions = interactions[message.id] {
                    entries.append(.post(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, message, interactions))
                    index += 1
                }
            }
        }

        if !data.instantPageInteractionsGraph.isEmpty {
            entries.append(.instantPageInteractionsTitle(presentationData.theme, presentationData.strings.Stats_InstantViewInteractionsTitle))
            entries.append(.instantPageInteractionsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.instantPageInteractionsGraph, .step))
        }
    }
    
    return entries
}

public func channelStatsController(context: AccountContext, peerId: PeerId, cachedPeerData: CachedPeerData) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var navigateToMessageImpl: ((MessageId) -> Void)?
    
    let actionsDisposable = DisposableSet()
    let checkCreationAvailabilityDisposable = MetaDisposable()
    actionsDisposable.add(checkCreationAvailabilityDisposable)
    
    let dataPromise = Promise<ChannelStats?>(nil)
    let messagesPromise = Promise<MessageHistoryView?>(nil)
    
    var datacenterId: Int32 = 0
    if let cachedData = cachedPeerData as? CachedChannelData {
        datacenterId = cachedData.statsDatacenterId
    }
        
    let statsContext = ChannelStatsContext(postbox: context.account.postbox, network: context.account.network, datacenterId: datacenterId, peerId: peerId)
    let dataSignal: Signal<ChannelStats?, NoError> = statsContext.state
    |> map { state in
        return state.stats
    } |> afterNext({ [weak statsContext] stats in
        if let statsContext = statsContext, let stats = stats {
            if case .OnDemand = stats.interactionsGraph {
                statsContext.loadInteractionsGraph()
                statsContext.loadTopHoursGraph()
                statsContext.loadNewFollowersBySourceGraph()
                statsContext.loadViewsBySourceGraph()
                statsContext.loadLanguagesGraph()
                statsContext.loadInstantPageInteractionsGraph()
            }
        }
    })
    dataPromise.set(.single(nil) |> then(dataSignal))
    
    let arguments = StatsControllerArguments(context: context, loadDetailedGraph: { graph, x -> Signal<ChannelStatsGraph?, NoError> in
        return statsContext.loadDetailedGraph(graph, x: x)
    }, openMessage: { messageId in
        navigateToMessageImpl?(messageId)
    })
    
    let messageView = context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId), index: .upperBound, anchorIndex: .upperBound, count: 100, fixedCombinedReadStates: nil)
    |> map { messageHistoryView, _, _ -> MessageHistoryView? in
        return messageHistoryView
    }
    messagesPromise.set(.single(nil) |> then(messageView))
    
    let longLoadingSignal: Signal<Bool, NoError> = .single(false) |> then(.single(true) |> delay(1.5, queue: Queue.mainQueue()))
    
    let previousData = Atomic<ChannelStats?>(value: nil)
    
    let signal = combineLatest(context.sharedContext.presentationData, dataPromise.get(), messagesPromise.get(), longLoadingSignal)
    |> deliverOnMainQueue
    |> map { presentationData, data, messageView, longLoading -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let previous = previousData.swap(data)
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if data == nil {
            if longLoading {
                emptyStateItem = StatsEmptyStateItem(theme: presentationData.theme, strings: presentationData.strings)
            } else {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
        }
        
        let messages = messageView?.entries.map { $0.message }.sorted(by: { (lhsMessage, rhsMessage) -> Bool in
            return lhsMessage.timestamp > rhsMessage.timestamp
        })
        let interactions = data?.messageInteractions.reduce([MessageId : ChannelStatsMessageInteractions]()) { (map, interactions) -> [MessageId : ChannelStatsMessageInteractions] in
            var map = map
            map[interactions.messageId] = interactions
            return map
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.ChannelInfo_Stats), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: statsControllerEntries(data: data, messages: messages, interactions: interactions, presentationData: presentationData), style: .blocks, emptyStateItem: emptyStateItem, crossfadeState: previous == nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
        let _ = statsContext.state
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.didDisappear = { [weak controller] _ in
        controller?.clearItemNodesHighlight(animated: true)
    }
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c, animated: true)
        }
    }
    presentControllerImpl = { [weak controller] c, a in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: a)
        }
    }
    navigateToMessageImpl = { [weak controller] messageId in
        if let navigationController = controller?.navigationController as? NavigationController {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(messageId.peerId), subject: .message(messageId), keepStack: .always, useExisting: false, purposefulAction: {}))
        }
    }
    return controller
}