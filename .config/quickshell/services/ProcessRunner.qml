pragma Singleton
import QtQuick
import Quickshell.Io
import ".."

// Fire-and-forget process execution with optional failure feedback.
// Use for user-initiated actions where silent failure would be
// confusing (session actions, volume, wallpaper, theme, app launch).
// Do NOT use for background polling — polling failures should stay
// silent/retry-on-next-tick (see docs/superpowers/specs/2026-08-01-process-error-toasts-design.md, Non-goals).
QtObject {
    id: root

    // Repeat-failure suppression window. adjustVolume() runs once per
    // scroll-wheel tick (10-20+ per gesture) and setRandom() runs once per
    // monitor, so a broken `wpctl`/`awww` would otherwise stack that many
    // urgency-2 (never auto-dismissing) toasts. Same convention as
    // MediaService's _lastToastKey, but keyed per (appName, summary) with a
    // time window, since ProcessRunner is shared by unrelated call sites and
    // a single "last key" slot would let two alternating failures defeat it.
    readonly property int toastDedupMs: 3000
    property var _recentFailureToasts: ({})

    // How long a detached run stays observable for failure reporting.
    // See _detachedScript() — enforced by the wrapper shell, not by QML.
    readonly property int detachedGraceSeconds: 2

    // Single-quote a shell word: 'foo'\''bar' is the only encoding that
    // survives arbitrary content (session commands include literal quotes,
    // e.g. `hyprctl dispatch 'hl.dsp.exit()'`).
    function _shQuote(word) {
        return "'" + String(word).replace(/'/g, "'\\''") + "'"
    }

    // Detached runs need the child to outlive both the QML Process object and
    // Quickshell itself, while still reporting *near-term* launch failures.
    // Quickshell's Process gives us neither half of that on its own:
    //
    //   - `startDetached()` (Process, quickshell-io.qmltypes:192) detaches but
    //     emits no signals at all, so failures stay silent — that is the
    //     pre-migration behavior this feature exists to fix.
    //   - `running = false` is a terminate action, not an untrack action
    //     (IdleInhibitService relies on exactly that to stop systemd-inhibit).
    //   - Dropping the JS reference does not help: Qt.createQmlObject() parents
    //     the object to `root`, and parented objects are never garbage
    //     collected; if they were, the collector would run the destructor at an
    //     arbitrary later time and take the app down with it.
    //   - Leaving the Process alive instead leaks it (plus its stderr buffer)
    //     for the app's entire lifetime.
    //
    // So the grace window lives in the shell: background the real command in a
    // subshell, race it against a `sleep`, and exit with whichever finishes
    // first (`wait -n`). A command that dies inside the window propagates its
    // real exit status; one that is still alive when the sleep wins exits 0 and
    // is reparented to init the moment this wrapper exits. Either way the QML
    // Process object lives at most `detachedGraceSeconds` and is destroyed
    // normally. stdout/stderr of the backgrounded command go to /dev/null
    // rather than being inherited: Quickshell pipes child stdio even when no
    // parser is attached, and that pipe's read end dies with the Process
    // object, which would SIGPIPE any chatty app that outlives the window.
    // Cost of that: the failure toast body is the exit code, not stderr.
    // Requires bash (`wait -n`); all detached call sites already use bash.
    function _detachedScript(command) {
        var quoted = []
        for (var i = 0; i < command.length; i++)
            quoted.push(root._shQuote(command[i]))
        return "{ " + quoted.join(" ") + "\n} >/dev/null 2>&1 &\n"
             + "sleep " + root.detachedGraceSeconds + " &\n"
             + "wait -n"
    }

    // opts: { appName, onFailureSummary, urgency, detached } — all but command
    // are optional. No onFailureSummary means failures are swallowed
    // exactly like today (opt-in, not a blanket behavior change).
    // detached: true for commands that must outlive Quickshell (app launch,
    // session actions); leave it off for short-lived commands.
    function run(command, opts) {
        opts = opts || {}
        var detached = opts.detached === true
        // No stderr collector for detached runs — the wrapper sends the real
        // command's output to /dev/null, so there is nothing to collect and
        // nothing to buffer for the app's lifetime.
        var p = Qt.createQmlObject(
            detached
                ? 'import Quickshell.Io; Process {}'
                : 'import Quickshell.Io; Process { stderr: StdioCollector { waitForEnd: true } }',
            root)
        p.command = detached ? ["bash", "-c", root._detachedScript(command)] : command

        function reportFailure(detail) {
            if (!opts.onFailureSummary) return
            var appName = opts.appName || "Shell"
            if (!root._shouldToast(appName + "|" + opts.onFailureSummary)) return
            NotificationService.notifyTransient({
                appName: appName,
                summary: opts.onFailureSummary,
                body: detail || "",
                urgency: opts.urgency !== undefined ? opts.urgency : 2
            })
        }

        // Process's `errorOccurred` is not exposed as a connectable Signal on
        // this Quickshell version (checked /usr/lib/qt6/qml/Quickshell/Io/
        // quickshell-io.qmltypes — Process only declares `started` and
        // `exited` as real Signals; `onErrorOccurred` there is an internal
        // reload-hook Method, and calling .connect() on it throws). `exited`
        // is the only failure signal available: commands run through a shell
        // wrapper (["bash","-c",...] / ["/bin/sh","-c",...]) still fire
        // `exited` with a nonzero code even if the *inner* binary is missing
        // (the shell itself starts and reports "command not found"). Direct,
        // unwrapped binaries (AudioService's `wpctl`, WallpaperService's
        // `awww`) are the one gap: if the binary itself fails to spawn,
        // no signal fires and the failure stays silent — same as today's
        // baseline, not a regression.
        p.exited.connect(function(exitCode, exitStatus) {
            // QProcess::ExitStatus — 0 is NormalExit, 1 is CrashExit. A
            // signal-killed process reports CrashExit with an exitCode that is
            // not meaningful (0 on some platforms), so it must be checked
            // separately. Guarded against `undefined` so an unmarshalled enum
            // degrades to the exit-code-only check rather than toasting on
            // every success.
            var crashed = exitStatus !== undefined && exitStatus !== 0
            if (exitCode !== 0 || crashed) {
                var stderrText = p.stderr ? p.stderr.text : ""
                var detail = stderrText
                    ? stderrText.trim().split("\n")[0]
                    : (crashed ? "terminated abnormally" : "exit code " + exitCode)
                reportFailure(detail)
            }
            p.destroy()
        })
        p.running = true
    }

    // Returns true if `key` has not toasted within toastDedupMs. The stamp is
    // refreshed on every failure, suppressed or not, so a continuous burst
    // (a scroll gesture) only ever yields the first toast, and the window
    // starts counting from the last failure rather than the first.
    function _shouldToast(key) {
        var now = Date.now()
        var last = root._recentFailureToasts[key]
        root._recentFailureToasts[key] = now
        return last === undefined || (now - last) >= root.toastDedupMs
    }
}
