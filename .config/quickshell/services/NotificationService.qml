pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

QtObject {
    id: root

    property var  notifications: []
    property bool doNotDisturb:  false

    // DesktopEntries (Quickshell's built-in .desktop scanner, used by
    // NotificationContent.qml to resolve desktopEntry/appName to a real
    // icon) is itself a lazily-instantiated singleton - its async directory
    // scan doesn't start until something reads a property on it via a real
    // binding, not merely a function-body reference (same gotcha as
    // ClipboardService, see AppLauncher.qml's _clipboardWarmup). Without
    // this, the first notifications right after shell startup could race
    // the scan and miss a resolvable icon.
    property int _desktopEntriesWarmup: DesktopEntries.applications.values.length

    signal notificationAdded(var notification)
    signal notificationClosed(int id)

    property var _server: NotificationServer {
        keepOnReload: true

        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true
        actionIconsSupported: true

        onNotification: function(notif) {
            notif.tracked = true

            var entry = {
                id:             notif.id,
                appName:        notif.appName,
                summary:        notif.summary,
                body:           notif.body,
                icon:           notif.appIcon,
                image:          notif.image,
                urgency:        notif.urgency,
                expireTimeout:  notif.expireTimeout,
                actions:        notif.actions,
                hasActionIcons: notif.hasActionIcons,
                resident:       notif.resident,
                transient:      notif.transient,
                desktopEntry:   notif.desktopEntry,
                timestamp:      new Date(),
                seen:           false,
                notif:          notif
            }
            var list = root.notifications.slice()
            list.unshift(entry)
            if (list.length > 100) list.length = 100
            root.notifications = list
            root.notificationAdded(entry)

            notif.closed.connect(function(reason) {
                root.dismiss(notif.id)
            })
        }
    }

    property int _transientId: -1

    function notifyTransient(data) {
        var entry = {
            id:        _transientId--,
            appName:   data.appName,
            summary:   data.summary,
            body:      data.body || "",
            icon:      data.icon || "",
            urgency:   data.urgency !== undefined ? data.urgency : 1,
            timestamp: new Date()
        }
        root.notificationAdded(entry)
    }

    function dismiss(id) {
        var entry = notifications.find(function(n) { return n.id === id })
        notifications = notifications.filter(function(n) { return n.id !== id })
        if (entry && entry.notif) entry.notif.tracked = false
        notificationClosed(id)
    }

    function dismissAll() {
        var removed = notifications
        notifications = []
        removed.forEach(function(n) {
            if (n.notif) n.notif.tracked = false
        })
    }

    function markAllSeen() {
        var list = root.notifications.map(function(n) {
            if (n.seen) return n
            var copy = Object.assign({}, n)
            copy.seen = true
            return copy
        })
        root.notifications = list
    }
}
