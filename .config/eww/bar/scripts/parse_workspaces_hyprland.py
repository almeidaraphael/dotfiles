#!/usr/bin/env python3

"""
parse_workspaces_hyprland.py

Goes through all workspaces with windows using hyprctrl
And returns a JSON list of text for each workspace, usually a Nerd font icon
"""

import json
import subprocess

import socket
import os, os.path
from collections import deque

# EDIT THIS FILE FOR YOUR OWN ICONS
# To find process name, you can use
# ps aux | grep <process>
# Then truncate the process down to 15 charactes
# ex:
# /bin/plasma-systemmonitor => plasma-systemmo
# 
# This will also match on the first word of window titles
icon_map_path = "/home/pheiow/.config/eww/bar/scripts/workspaces_map.json"

HYPRLAND_INSTANCE_SIGNATURE = os.getenv('HYPRLAND_INSTANCE_SIGNATURE')
SOCKET_PATH = f"/tmp/hypr/{HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

WORKSPACE_ACTIVE_CLASS_TEMPLATE = "active-{}"
WORKSPACE_INACTIVE_CLASS = "inactive"

def main():
    with open(icon_map_path, "r") as icon_map_buf:
        icon_map = json.loads(icon_map_buf.read())
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as socket_client:
        socket_client.connect(SOCKET_PATH)

        while True:
            # For now, do nothing about the actual content, and simply use it to refresh
            monitor_str = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True)
            monitor_json = json.loads(monitor_str.stdout)

            active_workspace_per_monitor = {
                monitor["id"]: monitor["activeWorkspace"]["name"]
                for monitor in monitor_json
            }

            color_class_per_workspace = {
                monitor["activeWorkspace"]["name"]: (
                    WORKSPACE_ACTIVE_CLASS_TEMPLATE.format(monitor["id"])
                )
                for monitor in monitor_json
            }

            activewindow_str = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True)
            activewindow_json = json.loads(activewindow_str.stdout)
            if 'title' in activewindow_json:
                current_window_title = activewindow_json['title']
                if len(current_window_title) > 100:
                    current_window_title = current_window_title[:50] + "..." + current_window_title[-50:]
            else:
                current_window_title = ""

            clients_str = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True).stdout
            clients_json = json.loads(clients_str)

            icons = {}
            for client in clients_json:
                workspace_name = client['workspace']['name']
                workspace = 'S' if workspace_name == 'special:scratchpad' else workspace_name
                processname = client['class']
                win_title = client['title']

                if processname == "":
                    continue

                # First match on window title
                win_title = win_title.split(" ")[0]
                
                if win_title in icon_map:
                    icon = icon_map[win_title]
                elif processname in icon_map:
                    icon = icon_map[processname]
                else:
                    icon = icon_map['no-icon']

                if workspace in icons:
                    icons[workspace]["icons"].append(icon)
                else:
                    icons[workspace] = {
                        "icons": [icon],
                        "workspace": workspace,
                        "process": processname,
                        # active-${MONITOR_ID}
                        # inactive
                        "color_class": color_class_per_workspace.get(workspace, WORKSPACE_INACTIVE_CLASS),
                    }

            # Guarantees that even if the current workspace is empty, it will
            # still be displayed
            for monitor_id, workspace in active_workspace_per_monitor.items():
                if workspace not in icons:
                    icons[workspace] = {
                        "icons": [icon_map["default"]],
                        "workspace": workspace,
                        "process": "<empty>",
                        "color_class": color_class_per_workspace.get(workspace, WORKSPACE_INACTIVE_CLASS),
                    }

            payload = {
                "title": current_window_title,
                "icons": [icons[i] for i in sorted(icons.keys())]
            }

            # This is a bit expensive, but there are only a few elements anyway
            print(json.dumps(payload), flush=True)

            # Block on next call
            socket_client.recv(1024).decode()

if __name__ == "__main__":
    main()