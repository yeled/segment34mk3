import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Weather;

(:background)
class Segment34ServiceDelegate extends System.ServiceDelegate {

    function initialize() {
        System.ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var weatherProvider = Application.Properties.getValue("weatherProvider") as Number;

        if (weatherProvider != 1 && weatherProvider != 2 && weatherProvider != 3) { return; }

        // OWM and Tomorrow.io require API keys; Open-Meteo does not.
        var apiKey = "" as String;
        if (weatherProvider == 1) {
            apiKey = Application.Properties.getValue("owmApiKey") as String;
            if (apiKey.length() == 0) { return; }
        } else if (weatherProvider == 3) {
            apiKey = Application.Properties.getValue("tomorrowApiKey") as String;
            if (apiKey.length() == 0) { return; }
        }

        // Resolve location: shared between providers.
        // Prefer the manual location override; fall back to Garmin's last known position.
        var lat = 0.0f;
        var lon = 0.0f;
        var hasLocation = false;

        var locationOverride = Application.Properties.getValue("owmLocationOverride") as String;
        if (locationOverride != null && locationOverride.length() > 0) {
            var commaPos = locationOverride.find(",");
            if (commaPos != null && commaPos > 0) {
                var latStr = locationOverride.substring(0, commaPos);
                var lonStr = locationOverride.substring(commaPos + 1, locationOverride.length());
                if (latStr != null && lonStr != null) {
                    var parsedLat = latStr.toFloat();
                    var parsedLon = lonStr.toFloat();
                    if (parsedLat != null && parsedLon != null) {
                        lat = parsedLat;
                        lon = parsedLon;
                        hasLocation = true;
                    }
                }
            }
        }

        if (!hasLocation) {
            var garminCc = Weather.getCurrentConditions();
            if (garminCc == null || garminCc.observationLocationPosition == null) { return; }
            var deg = garminCc.observationLocationPosition.toDegrees();
            lat = (deg[0] as Decimal).toFloat();
            lon = (deg[1] as Decimal).toFloat();
        }

        // Rate-limit: skip fetch if data is fresh and location hasn't changed.
        var now = Time.now().value();
        var lastUpdate = Application.Storage.getValue("wx_last_update") as Number?;
        var interval = Application.Properties.getValue("owmRefreshInterval") as Number;
        if (lastUpdate != null && now - lastUpdate < interval && !locationChangedSignificantly(lat, lon)) {
            return;
        }

        if (weatherProvider == 1) {
            var service = new OpenWeatherService();
            service.fetchWeather(lat, lon, apiKey);
        } else if (weatherProvider == 2) {
            var service = new OpenMeteoService();
            service.fetchWeather(lat, lon);
        } else if (weatherProvider == 3) {
            var service = new TomorrowService();
            service.fetchWeather(lat, lon, apiKey);
        }
    }

    // Returns true if current position is >~55km from the stored weather location.
    hidden function locationChangedSignificantly(lat as Float, lon as Float) as Boolean {
        var stored = Application.Storage.getValue("current_conditions") as Dictionary?;
        if (stored == null) { return false; }
        var pos = stored.get("observationLocationPosition") as Array?;
        if (pos == null) { return false; }
        var latDiff = lat - (pos[0] as Decimal).toFloat();
        var lonDiff = lon - (pos[1] as Decimal).toFloat();
        if (latDiff < 0.0f) { latDiff = -latDiff; }
        if (lonDiff < 0.0f) { lonDiff = -lonDiff; }
        return latDiff > 0.5f || lonDiff > 0.5f;
    }
}

