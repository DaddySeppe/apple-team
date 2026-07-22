import Foundation

#if canImport(DeviceActivity)
import DeviceActivity

final class MissionZebraDeviceActivityMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue == MissionZebraDeviceActivityShared.activityName else { return }
        let defaults = MissionZebraAppGroup.defaults
        let todayKey = MissionZebraDeviceActivityShared.dateKey()
        if defaults.string(forKey: MissionZebraDeviceActivityShared.lastEventDateKey) != todayKey {
            defaults.removeObject(forKey: MissionZebraDeviceActivityShared.deviceActivityUsageKey())
            defaults.removeObject(forKey: MissionZebraDeviceActivityShared.lastThresholdMinutesKey)
            defaults.set(todayKey, forKey: MissionZebraDeviceActivityShared.lastEventDateKey)
            defaults.synchronize()
        }
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
        let usageKey = MissionZebraDeviceActivityShared.deviceActivityUsageKey()
        let stableMinutes = max(defaults.integer(forKey: usageKey), minutes)
        defaults.set(stableMinutes, forKey: usageKey)
        defaults.set(stableMinutes, forKey: MissionZebraDeviceActivityShared.lastThresholdMinutesKey)
        defaults.set(MissionZebraDeviceActivityShared.dateKey(), forKey: MissionZebraDeviceActivityShared.lastEventDateKey)
        defaults.set(nowMillis, forKey: MissionZebraDeviceActivityShared.lastEventAtKey)
        defaults.synchronize()
    }
}
#else
final class MissionZebraDeviceActivityMonitor: NSObject {}
#endif
