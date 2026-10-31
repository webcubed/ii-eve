pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtPositioning

import qs.modules.common
// DateTime, Translation are siblings in qs.services and resolve via implicit
// directory import (this file lives in qs.services). Keep this anchor so a
// future move surfaces the dependency.

Singleton {
    id: root
    // 10 minute
    readonly property int fetchInterval: Config.options.bar.weather.fetchInterval * 60 * 1000
    // GPS doesn't need to follow a debug-tier fetchInterval; floor at 30 min.
    readonly property int gpsUpdateInterval: Math.max(root.fetchInterval, 30 * 60 * 1000)
    readonly property string city: Config.options.bar.weather.city
    readonly property bool useUSCS: Config.options.bar.weather.useUSCS
    readonly property string provider: Config.options.bar.weather.provider
    property bool gpsActive: Config.options.bar.weather.enableGPS

    // Re-render cached data without a network round-trip — both unit families
    // are derivable from the last raw response.
    onUseUSCSChanged: root._renderFromCache()
    // Debounce to avoid one fetch per keystroke when typing the city name in
    // Settings, and to coalesce rapid provider toggles.
    onCityChanged: refetchDebounce.restart()
    onProviderChanged: refetchDebounce.restart()

    onGpsActiveChanged: {
        if (gpsActive) {
            console.info("[WeatherService] Starting the GPS service.");
            positionSource.start();
        } else {
            positionSource.stop();
            root.location = { valid: false, lat: 0, lon: 0 };
            root.getData();
        }
    }

    Timer {
        id: refetchDebounce
        interval: 500
        repeat: false
        onTriggered: root.getData()
    }

    property var location: ({
        valid: false,
        lat: 0,
        lon: 0
    })

    property var data: ({
        uv: 0,
        humidity: "",
        sunrise: "",
        sunset: "",
        windDir: "",
        wCode: "",
        wDesc: "",
        city: "",
        wind: "",
        precip: "",
        visib: "",
        press: "",
        temp: "",
        tempFeelsLike: "",
        lastRefresh: "",
    })

    property bool forecastLoading: false
    property var forecastDaily: []      // [{date, maxC, minC, maxF, minF, code}]
    property var forecastHourly: []     // [{time, tempC, tempF, code}]

    // Last raw payloads kept for unit re-rendering without a refetch.
    property var _lastRawWttr: null
    property var _lastRawOpenMeteo: null

    function refineData(data) {
        let temp = {};
        temp.uv = data?.current?.uvIndex || 0;
        temp.humidity = (data?.current?.humidity || 0) + "%";
        temp.sunrise = data?.astronomy?.sunrise || "0.0";
        temp.sunset = data?.astronomy?.sunset || "0.0";
        temp.windDir = data?.current?.winddir16Point || "N";
        temp.wCode = data?.current?.weatherCode || "113";
        temp.wDesc = root.getWeatherDescription(temp.wCode);
        temp.city = data?.location?.areaName?.[0]?.value || "";
        temp.temp = "";
        temp.tempFeelsLike = "";
        if (root.useUSCS) {
            temp.wind = (data?.current?.windspeedMiles || 0) + " mph";
            temp.precip = (data?.current?.precipInches || 0) + " in";
            temp.visib = (data?.current?.visibilityMiles || 0) + " mi";
            // wttr.in's pressureInches is barometric pressure in inHg, not psi.
            temp.press = (data?.current?.pressureInches || 0) + " inHg";
            temp.temp += (data?.current?.temp_F || 0);
            temp.tempFeelsLike += (data?.current?.FeelsLikeF || 0);
            temp.temp += "°F";
            temp.tempFeelsLike += "°F";
        } else {
            temp.wind = (data?.current?.windspeedKmph || 0) + " km/h";
            temp.precip = (data?.current?.precipMM || 0) + " mm";
            temp.visib = (data?.current?.visibility || 0) + " km";
            temp.press = (data?.current?.pressure || 0) + " hPa";
            temp.temp += (data?.current?.temp_C || 0);
            temp.tempFeelsLike += (data?.current?.FeelsLikeC || 0);
            temp.temp += "°C";
            temp.tempFeelsLike += "°C";
        }
        temp.lastRefresh = DateTime.time;
        root.data = temp;
    }

    function _renderFromCache() {
        if (root._lastRawOpenMeteo) {
            root._refineOpenMeteo(root._lastRawOpenMeteo);
        } else if (root._lastRawWttr) {
            root.refineData(root._lastRawWttr);
            root.forecastDaily = root._lastRawWttr.daily || [];
            root.forecastHourly = root._lastRawWttr.hourly || [];
        }
    }

    // The fetch scripts print this marker on stdout when they fail, so failure is
    // something they state rather than something an empty stdout implies. An empty
    // stdout cannot mean "outage": a request that a newer one cancels (the startup
    // pair of a config-load fetch and the first GPS fix, a provider switch, a manual
    // refresh) is killed before it can print anything, and that empty result lands
    // after the newer request has already started — which is why every shell start
    // and refresh popped "weather service unreachable" while the next fetch was
    // succeeding.
    readonly property string fetchFailureMarker: "__weather_fetch_failed__"

    // Timestamp of the last failure notification, so one outage stays one
    // notification: a shell start alone issues several requests within seconds
    // (config load, provider change, first GPS fix), and the retry cadence is
    // minutes, not seconds.
    property double _lastFailureNotification: 0

    function _reportFetchFailure(message) {
        const now = Date.now();
        if (now - root._lastFailureNotification < 10 * 60 * 1000) return;
        root._lastFailureNotification = now;
        Quickshell.execDetached(["notify-send",
            Translation.tr("Weather Service"),
            message,
            "-a", "Shell"]);
    }

    function getData() {
        // Cancel any in-flight request before starting a new one — switching
        // provider or city while the previous fetch was still running used to
        // race and overwrite the new data with the stale response.
        fetcher.running = false;
        openMeteoFetcher.running = false;
        root.forecastLoading = true;
        if (root.provider === "open-meteo") {
            root._fetchOpenMeteo();
        } else {
            root._fetchWttr();
        }
    }

    function _fetchWttr() {
        const ua = (Config.options?.networking?.userAgent || "curl/7.68.0");
        const useGps = root.gpsActive && root.location.valid;
        let target;
        if (useGps) {
            target = `${Number(root.location.lat)},${Number(root.location.lon)}`;
        } else {
            target = root.city.trim();
        }
        const jqFilter =
            "{" +
            "current: .current_condition[0]," +
            "location: .nearest_area[0]," +
            "astronomy: .weather[0].astronomy[0]," +
            // Pick the midday slot but fall back to the last available slot or
            // the canonical "Clear" code so partial-day responses still render.
            "daily: [.weather[] | {date: .date, maxC: .maxtempC, minC: .mintempC, maxF: .maxtempF, minF: .mintempF, code: ((.hourly[4].weatherCode) // (.hourly | last | .weatherCode) // \"113\")}]," +
            "hourly: [.weather[0].hourly[], .weather[1].hourly[] | {time: .time, tempC: .tempC, tempF: .tempF, code: .weatherCode}]" +
            "}";
        // Pass user-controlled values as positional args ($1, $2, $3) instead of
        // string-interpolating them into the script. Bash quoting then makes
        // shell injection via city name impossible.
        const script =
            'set -o pipefail; ' +
            'TARGET="$1"; UA="$2"; MARK="$3"; ' +
            'ENC=$(printf %s "$TARGET" | jq -sRr @uri); ' +
            'curl -fsS --max-time 15 -H "User-Agent: $UA" "wttr.in/${ENC}?format=j1" | jq ' + "'" + jqFilter + "'" + ' || printf %s "$MARK"';
        fetcher.command = ["bash", "-c", script, "wttr-fetch", target, ua, root.fetchFailureMarker];
        fetcher.running = true;
    }

    function _fetchOpenMeteo() {
        const useGps = root.gpsActive && root.location.valid;
        if (!useGps && root.city.trim().length === 0) {
            // Geocoding with an empty name returns nothing; bail out loudly so
            // the spinner doesn't just stop with no UI feedback.
            root.forecastLoading = false;
            root._reportFetchFailure(Translation.tr("Set a city in Settings → Services → Weather, or enable GPS."));
            return;
        }

        const forecastParams =
            "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m,uv_index,visibility" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset" +
            "&hourly=temperature_2m,weather_code" +
            "&timezone=auto" +
            "&forecast_days=3";

        let argv;
        let script;
        if (useGps) {
            const lat = Number(root.location.lat);
            const lon = Number(root.location.lon);
            script =
                'set -o pipefail; ' +
                'LAT="$1"; LON="$2"; MARK="$3"; ' +
                'GEO=$(jq -nc --arg lat "$LAT" --arg lon "$LON" \'{latitude: ($lat|tonumber), longitude: ($lon|tonumber), name: ""}\') || { printf %s "$MARK"; exit 0; }; ' +
                'FC=$(curl -fsS --max-time 15 "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&' + forecastParams + '") || { printf %s "$MARK"; exit 0; }; ' +
                'printf %s "$FC" | jq --argjson geo "$GEO" \'. + {geo: $geo}\' || printf %s "$MARK"';
            argv = ["bash", "-c", script, "om-fetch", String(lat), String(lon), root.fetchFailureMarker];
        } else {
            script =
                'set -o pipefail; ' +
                'CITY="$1"; MARK="$2"; ' +
                'ENC=$(printf %s "$CITY" | jq -sRr @uri); ' +
                'GEO_RAW=$(curl -fsS --max-time 15 "https://geocoding-api.open-meteo.com/v1/search?name=${ENC}&count=1&language=en&format=json") || { printf %s "$MARK"; exit 0; }; ' +
                'GEO=$(printf %s "$GEO_RAW" | jq -c \'if (.results // [] | length) == 0 then null else {latitude: .results[0].latitude, longitude: .results[0].longitude, name: .results[0].name} end\'); ' +
                'if [ "$GEO" = "null" ] || [ -z "$GEO" ]; then printf %s "$MARK"; exit 0; fi; ' +
                'LAT=$(printf %s "$GEO" | jq -r \'.latitude\'); ' +
                'LON=$(printf %s "$GEO" | jq -r \'.longitude\'); ' +
                'FC=$(curl -fsS --max-time 15 "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&' + forecastParams + '") || { printf %s "$MARK"; exit 0; }; ' +
                'printf %s "$FC" | jq --argjson geo "$GEO" \'. + {geo: $geo}\' || printf %s "$MARK"';
            argv = ["bash", "-c", script, "om-fetch", root.city.trim(), root.fetchFailureMarker];
        }

        openMeteoFetcher.command = argv;
        openMeteoFetcher.running = true;
    }

    function getWeatherDescription(code) {
        const codeInt = parseInt(code);
        const descriptions = {
            "113": Translation.tr("Clear"),
            "116": Translation.tr("Partly Cloudy"),
            "119": Translation.tr("Cloudy"),
            "122": Translation.tr("Overcast"),
            "143": Translation.tr("Mist"),
            "176": Translation.tr("Patchy Rain"),
            "200": Translation.tr("Thundery Outbreaks"),
            "248": Translation.tr("Fog"),
            "266": Translation.tr("Light Drizzle"),
            "296": Translation.tr("Light Rain"),
            "302": Translation.tr("Moderate Rain"),
            "308": Translation.tr("Heavy Rain"),
            "326": Translation.tr("Light Snow"),
            "332": Translation.tr("Moderate Snow"),
            "338": Translation.tr("Heavy Snow"),
            "353": Translation.tr("Light Rain Shower"),
            "389": Translation.tr("Heavy Rain with Thunder")
        };

        if (descriptions[code]) {
            return descriptions[code];
        }

        let keys = Object.keys(descriptions).map(Number).sort((a, b) => a - b);
        let bestMatch = keys[0];

        for (let i = 0; i < keys.length; i++) {
            if (codeInt >= keys[i]) {
                bestMatch = keys[i];
            } else {
                break;
            }
        }

        return descriptions[bestMatch.toString()] || Translation.tr("Unknown");
    }

    function _wmoToWwoCode(wmo) {
        const map = {
            0: "113", 1: "116", 2: "116", 3: "122",
            45: "248", 48: "248",
            51: "266", 53: "266", 55: "266", 56: "266", 57: "266",
            61: "296", 63: "302", 65: "308", 66: "302", 67: "302",
            71: "326", 73: "332", 75: "338", 77: "326",
            80: "353", 81: "302", 82: "308", 85: "326", 86: "338",
            95: "200", 96: "389", 99: "389"
        };
        return map[parseInt(wmo)] || "113";
    }

    function _omWindDir(deg) {
        if (deg === undefined || deg === null) return "N";
        const dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        const idx = Math.round(((deg % 360 + 360) % 360) / 45) % 8;
        return dirs[idx];
    }

    function _refineOpenMeteo(parsed) {
        const cur = parsed.current || {};
        const daily = parsed.daily || {};
        const hourly = parsed.hourly || {};
        const geo = parsed.geo || {};

        const wCode = root._wmoToWwoCode(cur.weather_code);
        const tC = cur.temperature_2m;
        const fC = cur.apparent_temperature;

        const out = {};
        out.uv = cur.uv_index !== undefined ? cur.uv_index : 0;
        out.humidity = (cur.relative_humidity_2m !== undefined ? cur.relative_humidity_2m : 0) + "%";
        out.sunrise = (daily.sunrise && daily.sunrise[0]) ? daily.sunrise[0].slice(11, 16) : "0.0";
        out.sunset = (daily.sunset && daily.sunset[0]) ? daily.sunset[0].slice(11, 16) : "0.0";
        // Open-Meteo reports sunrise/sunset on the location's clock and echoes its
        // UTC offset; keeping the offset lets the sun arc stay right when the
        // machine's clock sits in another timezone.
        out.utcOffsetSeconds = parsed.utc_offset_seconds !== undefined ? Number(parsed.utc_offset_seconds) : undefined;
        out.windDir = root._omWindDir(cur.wind_direction_10m);
        out.wCode = wCode;
        out.wDesc = root.getWeatherDescription(wCode);
        out.city = geo.name || root.data.city || Translation.tr("Current Location");

        if (root.useUSCS) {
            out.wind = (cur.wind_speed_10m !== undefined ? (cur.wind_speed_10m * 0.621371).toFixed(1) : "0") + " mph";
            out.precip = (cur.precipitation !== undefined ? (cur.precipitation * 0.0393701).toFixed(2) : "0") + " in";
            out.visib = (cur.visibility !== undefined ? (cur.visibility / 1609).toFixed(1) : "0") + " mi";
            // hPa → inHg so the unit matches the wttr.in path.
            out.press = (cur.pressure_msl !== undefined ? (cur.pressure_msl * 0.02953).toFixed(2) : "0") + " inHg";
            out.temp = (tC !== undefined ? Math.round(tC * 9/5 + 32) : 0) + "°F";
            out.tempFeelsLike = (fC !== undefined ? Math.round(fC * 9/5 + 32) : 0) + "°F";
        } else {
            out.wind = (cur.wind_speed_10m !== undefined ? cur.wind_speed_10m : 0) + " km/h";
            out.precip = (cur.precipitation !== undefined ? cur.precipitation : 0) + " mm";
            out.visib = (cur.visibility !== undefined ? (cur.visibility / 1000).toFixed(1) : "0") + " km";
            out.press = (cur.pressure_msl !== undefined ? cur.pressure_msl : 0) + " hPa";
            out.temp = (tC !== undefined ? Math.round(tC) : 0) + "°C";
            out.tempFeelsLike = (fC !== undefined ? Math.round(fC) : 0) + "°C";
        }
        out.lastRefresh = DateTime.time;
        root.data = out;

        // Daily forecast: 3 days, °C source, both unit families derived locally.
        const dailyOut = [];
        const times = daily.time || [];
        for (let i = 0; i < times.length; i++) {
            const cMax = daily.temperature_2m_max ? daily.temperature_2m_max[i] : 0;
            const cMin = daily.temperature_2m_min ? daily.temperature_2m_min[i] : 0;
            dailyOut.push({
                date: times[i],
                maxC: Math.round(cMax).toString(),
                minC: Math.round(cMin).toString(),
                maxF: Math.round(cMax * 9/5 + 32).toString(),
                minF: Math.round(cMin * 9/5 + 32).toString(),
                code: root._wmoToWwoCode(daily.weather_code ? daily.weather_code[i] : 0)
            });
        }
        root.forecastDaily = dailyOut;

        // Hourly forecast: starting from current hour, up to 24 entries.
        const hourlyOut = [];
        const hTimes = hourly.time || [];
        const hTemps = hourly.temperature_2m || [];
        const hCodes = hourly.weather_code || [];
        const nowHour = new Date().getHours();
        let startIdx = hTimes.findIndex(iso => parseInt(iso.slice(11, 13)) >= nowHour);
        if (startIdx < 0) startIdx = 0;
        const end = Math.min(startIdx + 24, hTimes.length);
        for (let j = startIdx; j < end; j++) {
            const iso = hTimes[j];
            const c = hTemps[j] !== undefined ? hTemps[j] : 0;
            hourlyOut.push({
                // Match wttr.in's "0"/"300"/"600"/... format for downstream filtering.
                time: (parseInt(iso.slice(11, 13)) * 100).toString(),
                tempC: Math.round(c).toString(),
                tempF: Math.round(c * 9/5 + 32).toString(),
                code: root._wmoToWwoCode(hCodes[j])
            });
        }
        root.forecastHourly = hourlyOut;
    }

    Component.onCompleted: {
        if (!root.gpsActive) return;
        console.info("[WeatherService] Starting the GPS service.");
        positionSource.start();
    }

    Process {
        id: fetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) {
                    // Nothing on stdout: this request was cancelled by a newer one,
                    // which kills it before it can print anything. Not a failure.
                    return;
                }
                if (text.trim() === root.fetchFailureMarker) {
                    root.forecastLoading = false;
                    root._reportFetchFailure(Translation.tr("Failed to fetch weather data."));
                    return;
                }
                try {
                    const parsedData = JSON.parse(text);
                    root._lastRawWttr = parsedData;
                    root._lastRawOpenMeteo = null;
                    root.refineData(parsedData);
                    root.forecastDaily = parsedData.daily || [];
                    root.forecastHourly = parsedData.hourly || [];
                } catch (e) {
                    console.error(`[WeatherService] ${e.message}`);
                    root._reportFetchFailure(Translation.tr("Could not parse weather response."));
                }
                root.forecastLoading = false;
            }
        }
        stderr: StdioCollector {
            id: fetcherStderr
        }
    }

    Process {
        id: openMeteoFetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) {
                    // Nothing on stdout: this request was cancelled by a newer one,
                    // which kills it before it can print anything. Not a failure.
                    return;
                }
                if (text.trim() === root.fetchFailureMarker) {
                    root.forecastLoading = false;
                    root._reportFetchFailure(Translation.tr("City not found or weather service unreachable."));
                    return;
                }
                try {
                    const parsed = JSON.parse(text);
                    root._lastRawOpenMeteo = parsed;
                    root._lastRawWttr = null;
                    root._refineOpenMeteo(parsed);
                } catch (e) {
                    console.error(`[WeatherService] Open-Meteo parse error: ${e.message}`);
                    root._reportFetchFailure(Translation.tr("Could not parse weather response."));
                }
                root.forecastLoading = false;
            }
        }
        stderr: StdioCollector {
            id: openMeteoFetcherStderr
        }
    }

    PositionSource {
        id: positionSource
        updateInterval: root.gpsUpdateInterval

        onPositionChanged: {
            // update the location if the given location is valid
            // if it fails getting the location, use the last valid location
            if (position.latitudeValid && position.longitudeValid) {
                // Reassign the whole object so QML notifies binding consumers
                // (mutating var fields silently does not fire change signals).
                root.location = {
                    valid: true,
                    lat: position.coordinate.latitude,
                    lon: position.coordinate.longitude
                };
                // console.info(`📍 Location: ${position.coordinate.latitude}, ${position.coordinate.longitude}`);
                root.getData();
                // if can't get initialized with valid location deactivate the GPS
            } else {
                root.gpsActive = root.location.valid;
                console.error("[WeatherService] Failed to get the GPS location.");
            }
        }

        onValidityChanged: {
            if (!positionSource.valid) {
                positionSource.stop();
                root.location = { valid: false, lat: 0, lon: 0 };
                root.gpsActive = false;
                Quickshell.execDetached(["notify-send", Translation.tr("Weather Service"), Translation.tr("Cannot find a GPS service. Using the fallback method instead."), "-a", "Shell"]);
                console.error("[WeatherService] Could not aquire a valid backend plugin.");
            }
        }
    }

    Timer {
        running: !root.gpsActive
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: !root.gpsActive
        onTriggered: root.getData()
    }
}
