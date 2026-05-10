import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Weather;

(:background)
class TomorrowService {

    hidden var _lat as Float = 0.0;
    hidden var _lon as Float = 0.0;

    function initialize() {}

    // Tomorrow.io v4: realtime endpoint for current conditions, forecast endpoint
    // for hourly/daily. Default units are metric (C, m/s, mm/hr) which matches
    // what storeWeatherData expects.
    function fetchWeather(lat as Float, lon as Float, apiKey as String) as Void {
        _lat = lat;
        _lon = lon;
        var locStr = lat.toString() + "," + lon.toString();
        Communications.makeWebRequest(
            "https://api.tomorrow.io/v4/weather/realtime",
            { "location" => locStr, "apikey" => apiKey, "units" => "metric" },
            { :method => Communications.HTTP_REQUEST_METHOD_GET,
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onCurrentResponse)
        );
        Communications.makeWebRequest(
            "https://api.tomorrow.io/v4/weather/forecast",
            { "location" => locStr, "apikey" => apiKey, "units" => "metric", "timesteps" => "1h,1d" },
            { :method => Communications.HTTP_REQUEST_METHOD_GET,
              :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
            method(:onForecastResponse)
        );
    }

    function onCurrentResponse(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode == 401 || responseCode == 403) {
            Application.Storage.setValue("wx_error", "TIO: INVALID API KEY");
            return;
        }
        if (responseCode != 200 || data == null) {
            return;
        }
        Application.Storage.deleteValue("wx_error");

        var now = Time.now().value();
        var cc_data = {};

        var dataNode = data.get("data") as Dictionary?;
        var values = (dataNode != null) ? (dataNode.get("values") as Dictionary?) : null;
        if (values != null) {
            var temp = values.get("temperature");
            if (temp != null) { cc_data["temperature"] = (temp as Float).toNumber(); }
            var feelsLike = values.get("temperatureApparent");
            if (feelsLike != null) { cc_data["feelsLikeTemperature"] = (feelsLike as Float).toFloat(); }
            var humidity = values.get("humidity");
            if (humidity != null) { cc_data["relativeHumidity"] = (humidity as Float).toNumber(); }
            var windSpeed = values.get("windSpeed");
            if (windSpeed != null) { cc_data["windSpeed"] = (windSpeed as Float).toFloat(); }
            var windDir = values.get("windDirection");
            if (windDir != null) { cc_data["windBearing"] = (windDir as Float).toNumber(); }
            var windGust = values.get("windGust");
            if (windGust != null) { cc_data["windGust"] = (windGust as Float).toFloat(); }
            var precip = values.get("precipitationIntensity");
            if (precip != null && (precip as Float) > 0.0f) {
                cc_data["precipitationAmount"] = (precip as Float).toFloat();
            }
            var pop = values.get("precipitationProbability");
            if (pop != null) { cc_data["precipitationChance"] = (pop as Float).toNumber(); }
            var wCode = values.get("weatherCode");
            if (wCode != null) { cc_data["condition"] = tomorrowCodeToGarmin(wCode as Number); }
            var uv = values.get("uvIndex");
            if (uv != null) { cc_data["uvIndex"] = (uv as Float).toFloat(); }
        }

        // Daily high/low patched in by onForecastResponse if it has run.
        var fHigh = Application.Storage.getValue("owm_forecast_high");
        var fLow  = Application.Storage.getValue("owm_forecast_low");
        if (fHigh != null) { cc_data["highTemperature"] = fHigh as Number; }
        if (fLow  != null) { cc_data["lowTemperature"]  = fLow  as Number; }

        cc_data["observationLocationPosition"] = [_lat, _lon];
        cc_data["observationTime"] = now;
        cc_data["timestamp"] = now;
        Application.Storage.setValue("current_conditions", cc_data);
        Application.Storage.setValue("wx_last_update", now);
        var interval = Application.Properties.getValue("owmRefreshInterval") as Number;
        Background.registerForTemporalEvent(new Time.Duration(interval));
    }

    function onForecastResponse(responseCode as Number, data as Dictionary?) as Void {
        if (responseCode != 200 || data == null) { return; }

        var timelines = data.get("timelines") as Dictionary?;
        if (timelines == null) { return; }

        var hourly = timelines.get("hourly") as Array?;
        var hf_data = [] as Array<Dictionary>;
        var now = Time.now().value();
        if (hourly != null) {
            // Cap to ~8 hours like the other providers.
            var maxEntries = hourly.size() < 8 ? hourly.size() : 8;
            for (var i = 0; i < maxEntries; i++) {
                var entry = hourly[i] as Dictionary;
                var values = entry.get("values") as Dictionary?;
                if (values == null) { continue; }
                var tmp = {} as Dictionary;

                // Tomorrow.io returns ISO-8601 timestamps. Approximate by stepping
                // one hour from "now" since the slots are sequential hourly.
                tmp["forecastTime"] = now + (i * 3600);

                var temp = values.get("temperature");
                if (temp != null) { tmp["temperature"] = (temp as Float).toNumber(); }
                var pop = values.get("precipitationProbability");
                if (pop != null) { tmp["precipitationChance"] = (pop as Float).toNumber(); }
                var precip = values.get("precipitationIntensity");
                if (precip != null) {
                    var pa = (precip as Float).toFloat();
                    if (pa > 0.0f) { tmp["precipitationAmount"] = pa; }
                }
                var wCode = values.get("weatherCode");
                if (wCode != null) { tmp["condition"] = tomorrowCodeToGarmin(wCode as Number); }
                var wSpeed = values.get("windSpeed");
                if (wSpeed != null) { tmp["windSpeed"] = (wSpeed as Float).toFloat(); }
                var wDir = values.get("windDirection");
                if (wDir != null) { tmp["windBearing"] = (wDir as Float).toNumber(); }
                var wGust = values.get("windGust");
                if (wGust != null) { tmp["windGust"] = (wGust as Float).toFloat(); }
                var uv = values.get("uvIndex");
                if (uv != null) { tmp["uvIndex"] = (uv as Float).toFloat(); }
                hf_data.add(tmp);
            }
        }
        Application.Storage.setValue("hourly_forecast", hf_data);

        // Daily block: today's high/low (index 0).
        var daily = timelines.get("daily") as Array?;
        var dailyHigh = null as Number?;
        var dailyLow  = null as Number?;
        if (daily != null && daily.size() > 0) {
            var d0 = daily[0] as Dictionary;
            var dValues = d0.get("values") as Dictionary?;
            if (dValues != null) {
                var tMax = dValues.get("temperatureMax");
                var tMin = dValues.get("temperatureMin");
                if (tMax != null) { dailyHigh = (tMax as Float).toNumber(); }
                if (tMin != null) { dailyLow  = (tMin as Float).toNumber(); }
            }
        }
        if (dailyHigh != null) { Application.Storage.setValue("owm_forecast_high", dailyHigh); }
        if (dailyLow  != null) { Application.Storage.setValue("owm_forecast_low",  dailyLow); }

        // Patch daily high/low into current_conditions if it already exists.
        var cc = Application.Storage.getValue("current_conditions") as Dictionary?;
        if (cc != null) {
            if (dailyHigh != null) { cc["highTemperature"] = dailyHigh as Number; }
            if (dailyLow  != null) { cc["lowTemperature"]  = dailyLow  as Number; }
            Application.Storage.setValue("current_conditions", cc);
        }
    }

    // Maps Tomorrow.io weatherCode to Garmin Weather.Condition enum (0–53).
    static function tomorrowCodeToGarmin(code as Number) as Number {
        if (code == 1000) { return 0; }   // Clear, Sunny
        if (code == 1100) { return 1; }   // Mostly Clear → Partly Cloudy
        if (code == 1101) { return 1; }   // Partly Cloudy
        if (code == 1102) { return 2; }   // Mostly Cloudy
        if (code == 1001) { return 20; }  // Cloudy / Overcast
        if (code == 2000) { return 8; }   // Fog
        if (code == 2100) { return 8; }   // Light Fog
        if (code == 4000) { return 14; }  // Drizzle → Light Rain
        if (code == 4001) { return 3; }   // Rain
        if (code == 4200) { return 14; }  // Light Rain
        if (code == 4201) { return 15; }  // Heavy Rain
        if (code == 5000) { return 4; }   // Snow
        if (code == 5001) { return 16; }  // Flurries → Light Snow
        if (code == 5100) { return 16; }  // Light Snow
        if (code == 5101) { return 17; }  // Heavy Snow
        if (code == 6000) { return 32; }  // Freezing Drizzle
        if (code == 6001) { return 32; }  // Freezing Rain
        if (code == 6200) { return 32; }  // Light Freezing Rain
        if (code == 6201) { return 32; }  // Heavy Freezing Rain
        if (code == 7000) { return 33; }  // Ice Pellets / Sleet
        if (code == 7101) { return 33; }  // Heavy Ice Pellets
        if (code == 7102) { return 33; }  // Light Ice Pellets
        if (code == 8000) { return 6; }   // Thunderstorm
        return 53; // Unknown
    }
}
