import Foundation

#if canImport(DeviceActivity)
import DeviceActivity

final class MissionZebraDeviceActivityMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue == MissionZebraDeviceActivityShared.activityName else { return }
        let defaults = MissionZebraAppGroup.defaults
        defaults.removeObject(forKey: MissionZebraDeviceActivityShared.deviceActivityUsageKey())
        defaults.removeObject(forKey: MissionZebraDeviceActivityShared.lastThresholdMinutesKey)
        defaults.set(MissionZebraDeviceActivityShared.dateKey(), forKey: MissionZebraDeviceActivityShared.lastEventDateKey)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue == MissionZebraDeviceActivityShared.activityName else { return }
        MissionZebraAppGroup.defaults.set(MissionZebraDeviceActivityShared.dateKey(), forKey: MissionZebraDeviceActivityShared.lastEventDateKey)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity.rawValue == MissionZebraDeviceActivityShared.activityName,
              let minutes = MissionZebraDeviceActivityShared.minutes(fromEventName: event.rawValue) else {
            return
        }

        let defaults = MissionZebraAppGroup.defaults
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        defaults.set(minutes, forKey: MissionZebraDeviceActivityShared.deviceActivityUsageKey())
        defaults.set(minutes, forKey: MissionZebraDeviceActivityShared.lastThresholdMinutesKey)
        defaults.set(MissionZebraDeviceActivityShared.dateKey(), forKey: MissionZebraDeviceActivityShared.lastEventDateKey)
        defaults.set(nowMillis, forKey: MissionZebraDeviceActivityShared.lastEventAtKey)
    }
}
#else
final class MissionZebraDeviceActivityMonitor: NSObject {}
#endif
