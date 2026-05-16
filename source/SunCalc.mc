// Sun/twilight calculation utilities

import Toybox.Lang;
import Toybox.Time;
import Toybox.Weather;

function getNextEvent(todayFirstEvent as Time.Moment?, todaySecondEvent as Time.Moment?, tomorrowFirstEvent as Time.Moment?, tomorrowSecondEvent as Time.Moment?, now as Time.Moment) as Lang.Array {
    if (todayFirstEvent == null || todaySecondEvent == null || tomorrowFirstEvent == null || tomorrowSecondEvent == null) {
        return [];
    }

    var first = todayFirstEvent as Time.Moment;
    if (first.lessThan(now)) {
        first = tomorrowFirstEvent as Time.Moment;
    }

    var second = todaySecondEvent as Time.Moment;
    if (second.lessThan(now)) {
        second = tomorrowSecondEvent as Time.Moment;
    }

    if (first.lessThan(second)) {
        return [first, true];
    }
    return [second, false];
}

function getNextSunEvent(weatherCondition as StoredWeather?) as Lang.Array {
    var now = Time.now();
    if (weatherCondition != null) {
        var loc = weatherCondition.observationLocationPosition;
        if (loc != null) {
            var tomorrow = Time.today().add(new Time.Duration(86401));
            var sunrise = Weather.getSunrise(loc, now);
            var sunset = Weather.getSunset(loc, now);
            var tomorrowSunrise = Weather.getSunrise(loc, tomorrow);
            var tomorrowSunset = Weather.getSunset(loc, tomorrow);
            return getNextEvent(sunrise, sunset, tomorrowSunrise, tomorrowSunset, now);
        }
    }
    return [];
}

function getNextCivilTwilightEvent(weatherCondition as StoredWeather?) as Lang.Array {
    var now = Time.now();
    if (weatherCondition != null) {
        var loc = weatherCondition.observationLocationPosition;
        if (loc != null) {
            var tomorrow = Time.today().add(new Time.Duration(86401));
            var sunrise = Weather.getSunrise(loc, now);
            var sunset = Weather.getSunset(loc, now);
            var tomorrowSunrise = Weather.getSunrise(loc, tomorrow);
            var tomorrowSunset = Weather.getSunset(loc, tomorrow);
            if (sunrise != null && sunset != null && tomorrowSunrise != null && tomorrowSunset != null) {
                var latDeg = loc.toDegrees()[0];
                var twilight = getCivilTwilight(latDeg as Double, sunrise, sunset);
                var tomorrowTwilight = getCivilTwilight(latDeg as Double, tomorrowSunrise, tomorrowSunset);
                if (twilight != null && tomorrowTwilight != null) {
                    return getNextEvent(twilight[0], twilight[1], tomorrowTwilight[0], tomorrowTwilight[1], now);
                }
            }
        }
    }
    return [];
}

function hoursToNextSunEvent(weatherCondition as StoredWeather?) as Lang.String {
    var nextSunEventArray = getNextSunEvent(weatherCondition);
    if (nextSunEventArray != null && nextSunEventArray.size() == 2) {
        var nextSunEvent = nextSunEventArray[0] as Time.Moment;
        var now = Time.now();
        // Converting seconds to hours
        var diff = (nextSunEvent.subtract(now)).value();
        if (diff >= 36000) { // No decimals if 10+ hours
            return (diff / 3600.0).format("%d");
        }
        return (diff / 3600.0).format("%.1f");
    }
    return "";
}
