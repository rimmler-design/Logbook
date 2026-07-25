import Testing
@testable import Logbook

@Suite("TimeFormat")
struct TimeFormatTests {

    // MARK: hms — full clock format

    @Test("hms: zero duration shows 00:00")
    func hmsZero() {
        #expect(TimeFormat.hms(0) == "00:00")
    }

    @Test("hms: negative duration clamps to 00:00")
    func hmsNegative() {
        #expect(TimeFormat.hms(-60) == "00:00")
    }

    @Test("hms: under one minute shows mm:ss")
    func hmsUnderOneMinute() {
        #expect(TimeFormat.hms(45) == "00:45")
        #expect(TimeFormat.hms(9) == "00:09")
    }

    @Test("hms: exactly one minute")
    func hmsOneMinute() {
        #expect(TimeFormat.hms(60) == "01:00")
    }

    @Test("hms: minutes and seconds without hours")
    func hmsMinutesAndSeconds() {
        #expect(TimeFormat.hms(125) == "02:05")  // 2m 5s
        #expect(TimeFormat.hms(3599) == "59:59") // 59m 59s
    }

    @Test("hms: exactly one hour")
    func hmsOneHour() {
        #expect(TimeFormat.hms(3600) == "1:00:00")
    }

    @Test("hms: hours, minutes and seconds")
    func hmsHoursMinutesSeconds() {
        #expect(TimeFormat.hms(3661) == "1:01:01")   // 1h 1m 1s
        #expect(TimeFormat.hms(7384) == "2:03:04")   // 2h 3m 4s
        #expect(TimeFormat.hms(36000) == "10:00:00") // 10h flat
    }

    @Test("hms: leading zero on minutes and seconds within hours")
    func hmsLeadingZeros() {
        #expect(TimeFormat.hms(3605) == "1:00:05") // 1h 0m 5s
        #expect(TimeFormat.hms(3660) == "1:01:00") // 1h 1m 0s
    }

    // MARK: hm — compact format

    @Test("hm: zero duration shows 0m")
    func hmZero() {
        #expect(TimeFormat.hm(0) == "0m")
    }

    @Test("hm: negative duration clamps to 0m")
    func hmNegative() {
        #expect(TimeFormat.hm(-300) == "0m")
    }

    @Test("hm: under one hour shows minutes only")
    func hmUnderOneHour() {
        #expect(TimeFormat.hm(60) == "1m")
        #expect(TimeFormat.hm(300) == "5m")
        #expect(TimeFormat.hm(3540) == "59m")
    }

    @Test("hm: seconds are truncated, not rounded")
    func hmSecondsTruncated() {
        // 89 seconds = 1 minute and 29 seconds → shows 1m, not 2m
        #expect(TimeFormat.hm(89) == "1m")
    }

    @Test("hm: exactly one hour")
    func hmOneHour() {
        #expect(TimeFormat.hm(3600) == "1h 00m")
    }

    @Test("hm: hours and minutes")
    func hmHoursAndMinutes() {
        #expect(TimeFormat.hm(3660) == "1h 01m")   // 1h 1m
        #expect(TimeFormat.hm(7200) == "2h 00m")   // 2h
        #expect(TimeFormat.hm(9000) == "2h 30m")   // 2h 30m
        #expect(TimeFormat.hm(36000) == "10h 00m") // 10h
    }

    @Test("hm: leading zero on minutes within hours")
    func hmLeadingZeroMinutes() {
        #expect(TimeFormat.hm(3660) == "1h 01m")
        #expect(TimeFormat.hm(3720) == "1h 02m")
    }
}
