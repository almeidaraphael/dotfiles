pragma Singleton
import QtQuick

QtObject {
    id: root

    property string condition:   ""
    property string temperature: ""
    property string icon:        ""
    property bool   loading:     true
    property bool   error:       false

    property var _timer: Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function refresh() {
        loading = true
        var location = ConfigService.weatherLocation || ""
        var unit = ConfigService.temperatureUnit === "F" ? "u" : "m"
        var url = "https://wttr.in/" + encodeURIComponent(location)
                  + "?format=j1&" + unit

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) { loading = false; error = true; return }
            try {
                var data = JSON.parse(xhr.responseText)
                var current = data.current_condition[0]
                temperature = ConfigService.temperatureUnit === "F"
                    ? current.temp_F + "°F"
                    : current.temp_C + "°C"
                condition = current.weatherDesc[0].value
                icon = _conditionIcon(parseInt(current.weatherCode))
                error = false
            } catch(e) { error = true }
            loading = false
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function _conditionIcon(code) {
        if (code === 113) return "󰖨"
        if (code === 116) return "󰖕"
        if (code === 119 || code === 122) return "󰖐"
        if (code >= 176 && code <= 263) return "󰖗"
        if (code >= 266 && code <= 296) return "󰖗"
        if (code >= 299 && code <= 395) return "󰖙"
        if (code >= 179 && code <= 260) return "󰖘"
        return "󰖑"
    }
}
