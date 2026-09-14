import Quickshell
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property var bar: null
  property string moduleName: ""
  property var settings: ({})
  // Availability per command name. Unanswered entries show (menu `when:`
  // semantics: only an explicit fail hides a row), so first paint is complete
  // and a later check can take a row away.
  property var available: ({})
  // TUI commands the rows launch. The bar injects settings.installers with the
  // exact paths when the module ships bundled (package/aur are stock commands
  // on PATH, flatpak is the plugin's own script); users wiring a standalone
  // copy fall back to the bare stock names.
  readonly property string packageCmd: root.installer("package", "omarchy-pkg-install")
  readonly property string aurCmd: root.installer("aur", "omarchy-pkg-aur-install")
  readonly property string flatpakCmd: root.installer("flatpak", "omarchy-pkg-flatpak-install")
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  width: button.implicitWidth
  height: button.implicitHeight

  function installer(key, fallback) {
    var configured = root.settings && root.settings.installers && root.settings.installers[key]
    return configured || fallback
  }

  function runTerminal(command) {
    if (!command) return
    root.bar.run("xdg-terminal-exec --app-id=org.omarchy.terminal " + command)
  }

  function checkCommands() {
    if (checkProc.running) return
    checkProc.collected = ""
    var cmds = [root.packageCmd, root.aurCmd, root.flatpakCmd, "flatpak"]
    checkProc.command = ["bash", "-lc",
      cmds.map(function(c) {
        return "command -v \"" + c + "\" >/dev/null 2>&1 && echo \"i:" + c + ":1\" || echo \"i:" + c + ":0\""
      }).join("; ")]
    checkProc.running = true
  }

  WidgetButton {
    id: button
    bar: root.bar
    text: "󰏓"
    tooltipText: "Install software"

    onPressed: function() {
      popup.open = !popup.open
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    owner: root
    bar: root.bar
    triggerMode: "click"
    padding: Style.space(6)
    contentWidth: fittedContentWidth(Style.space(250))
    contentHeight: fittedContentHeight(menuColumn.implicitHeight)

    onOpenChanged: function() {
      if (popup.open) root.checkCommands()
    }

    Column {
      id: menuColumn
      anchors.fill: parent
      spacing: Style.space(2)

      InstallRow {
        text: "Package (Arch repo)"
        icon: "󰏓"
        command: root.packageCmd
      }
      InstallRow {
        text: "AUR"
        icon: "󰣇"
        command: root.aurCmd
      }
      InstallRow {
        text: "Flatpak"
        icon: "󰈓"
        command: root.flatpakCmd
        extraCheck: "flatpak"
      }
    }
  }

  Process {
    id: checkProc
    property string collected: ""
    stdout: SplitParser {
      onRead: function(data) { checkProc.collected += data + "\n" }
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0 || exitStatus !== 0) return
      var next = root.available
      var lines = checkProc.collected.split("\n")
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line) continue
        var parts = line.split(":")
        if (parts.length !== 3) continue
        if (parts[0] !== "i") continue
        next[parts[1]] = parts[2] === "1"
      }
      root.available = {}
      for (var k in next) root.available[k] = next[k]
    }
  }

  component InstallRow: Item {
    id: row
    required property string text
    required property string icon
    required property string command
    property string extraCheck: ""
    width: menuColumn.width
    implicitHeight: rowButton.implicitHeight
    visible: root.available != null && root.available[row.command] !== false
             && (row.extraCheck === "" || root.available[row.extraCheck] !== false)

    Button {
      id: rowButton
      anchors.fill: parent
      leftAlign: true
      iconText: row.icon
      text: row.text
      foreground: root.bar ? root.bar.foreground : Color.foreground
      iconSize: Style.font.body
      fontSize: Style.font.bodySmall
      horizontalPadding: Style.space(10)
      verticalPadding: Style.space(4)
      onClicked: {
        popup.open = false
        root.runTerminal(row.command)
      }
    }
  }
}
