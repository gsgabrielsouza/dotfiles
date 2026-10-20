#!/usr/bin/env python3
import json
import urllib.request

RAIN = {
    176, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314, 317, 320,
    353, 356, 359, 362, 365, 368, 374, 377,
}
SNOW = {179, 182, 185, 227, 230, 323, 326, 329, 332, 335, 338, 350, 371}
STORM = {200, 386, 389, 392, 395}
CLEAR = {113}


def alt_for(code: int) -> str:
    if code in CLEAR:
        return "clear"
    if code in STORM:
        return "storm"
    if code in SNOW:
        return "snow"
    if code in RAIN:
        return "rain"
    return "clouds"


def main() -> None:
    req = urllib.request.Request(
        "https://wttr.in/Curitiba?format=j1",
        headers={"User-Agent": "curl/8.0"},
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = json.load(resp)

    current = data["current_condition"][0]
    day = data["weather"][0]
    location = data["nearest_area"][0]["areaName"][0]["value"]
    temp = current["temp_C"]
    feels = current["FeelsLikeC"]
    desc = current["weatherDesc"][0]["value"]
    code = int(current["weatherCode"])
    mint = day["mintempC"]
    maxt = day["maxtempC"]
    alt = alt_for(code)

    payload = {
        "text": f"{temp}°C {location}",
        "tooltip": f"{location}\n{desc}\n{temp}°C (sensação {feels}°C)\nMín: {mint}°C  Máx: {maxt}°C",
        "alt": alt,
        "class": alt,
    }
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
