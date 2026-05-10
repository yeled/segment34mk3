import Toybox.Test;
import Toybox.Lang;

// Unit tests for TomorrowService.tomorrowCodeToGarmin()
// These test the Tomorrow.io weatherCode -> Garmin condition enum mapping.
// Run with: monkeyc --unit-test -d fenix7

(:test)
function testTomorrowCodeClear(logger as Test.Logger) as Boolean {
    return TomorrowService.tomorrowCodeToGarmin(1000) == 0;
}

(:test)
function testTomorrowCodeCloudVariants(logger as Test.Logger) as Boolean {
    return TomorrowService.tomorrowCodeToGarmin(1100) == 1   // Mostly Clear
        && TomorrowService.tomorrowCodeToGarmin(1101) == 1   // Partly Cloudy
        && TomorrowService.tomorrowCodeToGarmin(1102) == 2   // Mostly Cloudy
        && TomorrowService.tomorrowCodeToGarmin(1001) == 20; // Cloudy / Overcast
}

(:test)
function testTomorrowCodeFog(logger as Test.Logger) as Boolean {
    return TomorrowService.tomorrowCodeToGarmin(2000) == 8
        && TomorrowService.tomorrowCodeToGarmin(2100) == 8;
}

(:test)
function testTomorrowCodeRain(logger as Test.Logger) as Boolean {
    return TomorrowService.tomorrowCodeToGarmin(4000) == 14  // Drizzle → Light Rain
        && TomorrowService.tomorrowCodeToGarmin(4200) == 14  // Light Rain
        && TomorrowService.tomorrowCodeToGarmin(4001) == 3   // Rain
        && TomorrowService.tomorrowCodeToGarmin(4201) == 15; // Heavy Rain
}

(:test)
function testTomorrowCodeSnow(logger as Test.Logger) as Boolean {
    return TomorrowService.tomorrowCodeToGarmin(5001) == 16  // Flurries → Light Snow
        && TomorrowService.tomorrowCodeToGarmin(5100) == 16  // Light Snow
        && TomorrowService.tomorrowCodeToGarmin(5000) == 4   // Snow
        && TomorrowService.tomorrowCodeToGarmin(5101) == 17; // Heavy Snow
}

(:test)
function testTomorrowCodeFreezingRain(logger as Test.Logger) as Boolean {
    return TomorrowService.tomorrowCodeToGarmin(6000) == 32
        && TomorrowService.tomorrowCodeToGarmin(6001) == 32
        && TomorrowService.tomorrowCodeToGarmin(6200) == 32
        && TomorrowService.tomorrowCodeToGarmin(6201) == 32;
}

(:test)
function testTomorrowCodeIcePellets(logger as Test.Logger) as Boolean {
    return TomorrowService.tomorrowCodeToGarmin(7000) == 33
        && TomorrowService.tomorrowCodeToGarmin(7101) == 33
        && TomorrowService.tomorrowCodeToGarmin(7102) == 33;
}

(:test)
function testTomorrowCodeThunderstorm(logger as Test.Logger) as Boolean {
    return TomorrowService.tomorrowCodeToGarmin(8000) == 6;
}

(:test)
function testTomorrowCodeUnknown(logger as Test.Logger) as Boolean {
    return TomorrowService.tomorrowCodeToGarmin(0) == 53
        && TomorrowService.tomorrowCodeToGarmin(9999) == 53;
}
