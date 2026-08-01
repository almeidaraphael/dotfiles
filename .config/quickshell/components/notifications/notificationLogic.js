function iconSource(icon, resolveThemeIcon) {
    if (!icon) return ""
    if (icon.indexOf("/") === 0 || icon.indexOf("file://") === 0) return icon
    return resolveThemeIcon(icon)
}

function splitActions(actions) {
    var defaultAction = null
    var buttonActions = []
    for (var i = 0; i < actions.length; i++) {
        var a = actions[i]
        if (a.identifier === "default") {
            defaultAction = a
        } else {
            buttonActions.push(a)
        }
    }
    return { defaultAction: defaultAction, buttonActions: buttonActions }
}

function shouldAutoDismiss(urgency, expireTimeout) {
    if (expireTimeout === 0) return false
    return urgency !== 2
}

function actionDisplay(action, hasActionIcons) {
    if (hasActionIcons) return { mode: "icon", value: action.identifier }
    return { mode: "text", value: action.text }
}

// desktopEntry is an app *id* (e.g. "code"), not necessarily the icon-theme
// name (e.g. "vscode") - resolve it through the real .desktop entry first,
// only falling back to the raw id if no entry matches.
function resolveAppIcon(notification, lookupById) {
    if (notification.desktopEntry) {
        var entry = lookupById ? lookupById(notification.desktopEntry) : null
        if (entry && entry.icon) return entry.icon
        return notification.desktopEntry
    }

    var icon = notification.icon || ""
    if (icon && icon.indexOf("http://") !== 0 && icon.indexOf("https://") !== 0) return icon

    return notification.appName || ""
}

// Quickshell resolves the image-data/icon_data hint (a raw pixmap, no separate small icon -
// e.g. Firefox) into an "image://qsimage/..." url. It resolves image-path/image_path (a
// reference to an existing icon file, usually a small favicon - e.g. Chrome) into an
// "image://icon/..." url instead. That scheme is a reliable, self-contained signal for which
// kind of image this is - the raw hints map can't be used for this since Quickshell strips
// image-data/icon_data out of it once consumed.
function isRawPixmapImage(image) {
    return typeof image === "string" && image.indexOf("image://qsimage/") === 0
}

function resolveNotificationIcon(notification, resolveThemeIcon, lookupById, heuristicLookup) {
    if (notification.image && !isRawPixmapImage(notification.image)) return notification.image

    var direct = iconSource(resolveAppIcon(notification, lookupById), resolveThemeIcon)
    if (direct) return direct

    // Last resort: appName is usually a display string ("Visual Studio Code"),
    // rarely the icon-theme name itself ("vscode") - try a heuristic match
    // against installed .desktop entries before giving up to the caller's
    // own fallback.
    if (notification.appName && heuristicLookup) {
        var entry = heuristicLookup(notification.appName)
        if (entry && entry.icon) return resolveThemeIcon(entry.icon)
    }

    return ""
}

function extractBodyImage(body) {
    if (!body) return { image: "", text: body || "" }
    var match = body.match(/<img\b[^>]*\ssrc=["']([^"']+)["'][^>]*>/i)
    if (!match) return { image: "", text: body }
    return { image: match[1], text: (body.slice(0, match.index) + body.slice(match.index + match[0].length)).trim() }
}

function resolveNotificationBanner(notification) {
    if (notification.image && isRawPixmapImage(notification.image)) return notification.image
    return extractBodyImage(notification.body || "").image
}

if (typeof module !== "undefined") module.exports = {
    iconSource: iconSource,
    splitActions: splitActions,
    shouldAutoDismiss: shouldAutoDismiss,
    actionDisplay: actionDisplay,
    resolveAppIcon: resolveAppIcon,
    resolveNotificationIcon: resolveNotificationIcon,
    extractBodyImage: extractBodyImage,
    resolveNotificationBanner: resolveNotificationBanner
}
