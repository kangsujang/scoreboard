import CoreMedia

extension CMTime {
    var displayString: String {
        TimeFormatting.format(cmTime: self)
    }

    var safeSeconds: TimeInterval {
        guard isValid, !isIndefinite else { return 0 }
        return seconds
    }
}
