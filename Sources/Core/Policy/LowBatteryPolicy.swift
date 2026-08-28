import Foundation

public enum LowBatteryPolicy {
    public static let thresholdRange = 10...30
    public static let defaultThreshold = 15
    public static let hysteresis = 2

    public static func nextBlockedState(
        currentlyBlocked: Bool,
        battery: BatteryState,
        threshold: Int
    ) -> Bool {
        guard battery.hasInternalBattery,
              battery.powerSource == .battery,
              let percentage = battery.percentage
        else {
            return false
        }

        let safeThreshold = min(thresholdRange.upperBound, max(thresholdRange.lowerBound, threshold))
        let releaseThreshold = safeThreshold + hysteresis
        return currentlyBlocked ? percentage <= releaseThreshold : percentage <= safeThreshold
    }
}
