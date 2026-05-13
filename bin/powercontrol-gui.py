#!/usr/bin/env python3
"""
PowerControl GUI
"""

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib
import os

class ConfigEditor(Gtk.Window):
    def __init__(self):
        settings = Gtk.Settings.get_default()
        settings.set_property("gtk-application-prefer-dark-theme", True)
        super().__init__(title="PowerControl GUI")
        self.set_default_size(700, 600)
        headerbar = Gtk.HeaderBar()
        headerbar.set_show_close_button(True)
        headerbar.props.title = "PowerControl GUI"
        headerbar.set_decoration_layout("menu:minimize,maximize,close")
        self.set_titlebar(headerbar)
        self.reload_btn = Gtk.Button()
        reload_icon = Gtk.Image.new_from_icon_name("view-refresh-symbolic", Gtk.IconSize.BUTTON)
        self.reload_btn.set_image(reload_icon)
        self.reload_btn.set_tooltip_text("Reload")
        self.reload_btn.connect("clicked", self.on_reload_clicked)
        headerbar.pack_end(self.reload_btn)
        self.config_path = self.find_config_file()
        self.config_data = {}
        self.widgets = {}
        self.updating_constraints = False
        self.initial_load = True
        self.focusable_widgets = []

        if not self.config_path:
            self.show_error_dialog(
                "Config File Not Found",
                "Could not find config file at:\n"
                "/mnt/chromeos/MyFiles/Downloads/PowerControl_Config/config\n"
                "/mnt/shared/MyFiles/Downloads/PowerControl_Config/config\n"
                "/usr/local/bin/PowerControl_Config/config\n"
                "/home/chronos/user/MyFiles/Downloads/PowerControl_Config/config\n\n"
                "Please ensure the folder is shared to Crostini/Chard."
            )
            self.destroy()
            return

        self.create_ui()
        self.load_config()
        self.setup_constraints()
        self.setup_keyboard_navigation()
        self.initial_load = False

    def find_config_file(self):
        possible_paths = [
            "/mnt/chromeos/MyFiles/Downloads/PowerControl_Config/config",
            "/usr/local/bin/PowerControl_Config/config",
            os.path.expanduser("/home/chronos/user/MyFiles/Downloads/PowerControl_Config/config"),
            "/mnt/shared/MyFiles/Downloads/PowerControl_Config/config"
        ]
        for path in possible_paths:
            if os.path.exists(path):
                return path
        return None

    def setup_keyboard_navigation(self):
        self.connect("key-press-event", self.on_key_press)

    def on_key_press(self, widget, event):
        keyval = event.keyval
        if keyval == Gdk.KEY_Up or keyval == Gdk.KEY_Down:
            current_focus = self.get_focus()
            if current_focus is None:
                if self.focusable_widgets:
                    self.focusable_widgets[0].grab_focus()
                return True
            try:
                current_index = self.focusable_widgets.index(current_focus)
            except ValueError:
                return False
            if keyval == Gdk.KEY_Up:
                next_index = current_index - 1
                if next_index < 0:
                    next_index = len(self.focusable_widgets) - 1
            else:
                next_index = current_index + 1
                if next_index >= len(self.focusable_widgets):
                    next_index = 0
            self.focusable_widgets[next_index].grab_focus()
            return True
        return False

    def create_ui(self):
        main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        main_vbox.set_border_width(10)
        self.add(main_vbox)
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        main_vbox.pack_start(scrolled, True, True, 0)
        self.grid = Gtk.Grid()
        self.grid.set_column_spacing(5)
        self.grid.set_row_spacing(5)
        self.grid.set_margin_start(10)
        self.grid.set_margin_end(10)
        self.grid.set_margin_top(10)
        self.grid.set_margin_bottom(10)
        scrolled.add(self.grid)
        self.create_config_sections()
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        button_box.set_halign(Gtk.Align.CENTER)
        main_vbox.pack_start(button_box, False, False, 0)
        self.save_btn = Gtk.Button(label="Apply")
        self.save_btn.connect("clicked", self.on_save_clicked)
        button_box.pack_start(self.save_btn, False, False, 0)
        self.focusable_widgets.append(self.save_btn)
        exit_btn = Gtk.Button(label="Exit")
        exit_btn.connect("clicked", lambda x: self.destroy())
        button_box.pack_start(exit_btn, False, False, 0)
        self.focusable_widgets.append(exit_btn)

    def create_slider(self, min_val, max_val, step=1):
        scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, min_val, max_val, step)
        scale.set_digits(0 if step >= 1 else 1)
        scale.set_value_pos(Gtk.PositionType.RIGHT)
        scale.set_hexpand(True)
        scale.set_size_request(400, -1)
        return scale

    def create_switch(self):
        switch = Gtk.Switch()
        switch.set_halign(Gtk.Align.START)
        return switch

    def create_config_sections(self):
        sections = {
            "PowerControl": [
                ("MAX_TEMP",     "Maximum Temperature (°C)",  "slider", 30, 95,  1,   False),
                ("HOTZONE",      "Hotzone Temperature (°C)",   "slider", 30, 90,  1,   False),
                ("MIN_TEMP",     "Minimum Temperature (°C)",   "slider", 30, 90,  1,   False),
                ("MAX_PERF_PCT", "Maximum Performance (%)",    "slider", 10, 100, 1,   False),
                ("MIN_PERF_PCT", "Minimum Performance (%)",    "slider", 10, 100, 1,   False),
                ("RAMP_UP",      "Ramp Up Speed (%)",          "slider",  1, 50,  1,   False),
                ("RAMP_DOWN",    "Ramp Down Speed (%)",        "slider",  1, 50,  1,   False),
                ("CPU_POLL",     "CPU Poll Interval (s)",      "slider", 0.1, 5.0, 0.1, False),
            ],
            "Start on Boot": [
                ("STARTUP_POWERCONTROL", "PowerControl", "switch", None, None, None, False),
            ],
        }

        row = 0
        for section_name, fields in sections.items():
            header = Gtk.Label()
            header.set_markup(f"<b><big>{section_name}</big></b>")
            header.set_halign(Gtk.Align.START)
            header.set_margin_start(20)
            header.set_margin_top(15)
            header.set_margin_bottom(5)
            self.grid.attach(header, 0, row, 2, 1)
            row += 1
            separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
            separator.set_margin_bottom(5)
            separator.set_margin_start(10)
            self.grid.attach(separator, 0, row, 2, 1)
            row += 1
            for field in fields:
                key = field[0]
                label = field[1]
                widget_type = field[2]
                if key == "MAX_PERF_PCT":
                    lbl = Gtk.Label()
                    lbl.set_markup(f"<b>{label}</b>")
                else:
                    lbl = Gtk.Label(label=label)
                lbl.set_halign(Gtk.Align.END)
                lbl.set_margin_start(10)
                lbl.set_size_request(100, -1)
                self.grid.attach(lbl, 0, row, 1, 1)

                if widget_type == "slider":
                    min_val, max_val, step = field[3], field[4], field[5]
                    widget = self.create_slider(min_val, max_val, step)
                    self.grid.attach(widget, 1, row, 1, 1)
                    self.widgets[key] = widget
                    self.focusable_widgets.append(widget)
                elif widget_type == "switch":
                    widget = self.create_switch()
                    self.grid.attach(widget, 1, row, 1, 1)
                    self.widgets[key] = widget
                    self.focusable_widgets.append(widget)
                row += 1

    def setup_constraints(self):
        if all(k in self.widgets for k in ["MIN_TEMP", "HOTZONE", "MAX_TEMP"]):
            self.widgets["MIN_TEMP"].connect("value-changed", self.on_temp_constraint)
            self.widgets["HOTZONE"].connect("value-changed", self.on_temp_constraint)
            self.widgets["MAX_TEMP"].connect("value-changed", self.on_temp_constraint)
        if all(k in self.widgets for k in ["MIN_PERF_PCT", "MAX_PERF_PCT"]):
            self.widgets["MIN_PERF_PCT"].connect("value-changed", self.on_perf_constraint)
            self.widgets["MAX_PERF_PCT"].connect("value-changed", self.on_perf_constraint)

    def on_temp_constraint(self, scale):
        if self.updating_constraints:
            return
        self.updating_constraints = True
        min_temp = self.widgets["MIN_TEMP"].get_value()
        hotzone  = self.widgets["HOTZONE"].get_value()
        max_temp = self.widgets["MAX_TEMP"].get_value()
        if min_temp >= hotzone:
            self.widgets["MIN_TEMP"].set_value(hotzone - 1)
        if min_temp >= max_temp:
            self.widgets["MIN_TEMP"].set_value(max_temp - 2)
        if hotzone <= min_temp:
            self.widgets["HOTZONE"].set_value(min_temp + 1)
        if hotzone >= max_temp:
            self.widgets["HOTZONE"].set_value(max_temp - 1)
        if max_temp <= hotzone:
            self.widgets["MAX_TEMP"].set_value(hotzone + 1)
        if max_temp <= min_temp:
            self.widgets["MAX_TEMP"].set_value(min_temp + 2)
        self.updating_constraints = False

    def on_perf_constraint(self, scale):
        if self.updating_constraints:
            return
        self.updating_constraints = True
        min_perf = self.widgets["MIN_PERF_PCT"].get_value()
        max_perf = self.widgets["MAX_PERF_PCT"].get_value()
        if min_perf > max_perf:
            self.widgets["MAX_PERF_PCT"].set_value(min_perf)
        if max_perf < min_perf:
            self.widgets["MIN_PERF_PCT"].set_value(max_perf)
        self.updating_constraints = False

    def load_config(self):
        if not os.path.exists(self.config_path):
            self.show_error_dialog("Error", f"Config file not found: {self.config_path}")
            return
        self.config_data = {}
        try:
            with open(self.config_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        self.config_data[key.strip()] = value.strip()
            self.updating_constraints = True
            for key, widget in self.widgets.items():
                if key in self.config_data:
                    value = self.config_data[key]
                    if isinstance(widget, Gtk.Scale):
                        try:
                            widget.set_value(float(value))
                        except ValueError:
                            widget.set_value(0)
                    elif isinstance(widget, Gtk.Switch):
                        widget.set_active(value == "1")
            self.updating_constraints = False
        except Exception as e:
            self.updating_constraints = False
            self.show_error_dialog("Error", f"Failed to load config: {str(e)}")

    def save_config(self):
        try:
            with open(self.config_path, 'r') as f:
                lines = f.readlines()
            new_lines = []
            for line in lines:
                if line.strip() and not line.strip().startswith('#') and '=' in line:
                    key = line.split('=', 1)[0].strip()
                    if key in self.widgets:
                        widget = self.widgets[key]
                        if isinstance(widget, Gtk.Scale):
                            value = widget.get_value()
                            if key == "CPU_POLL":
                                new_value = f"{value:.1f}"
                            else:
                                new_value = str(int(value))
                        elif isinstance(widget, Gtk.Switch):
                            new_value = "1" if widget.get_active() else "0"
                        new_lines.append(f"{key}={new_value}\n")
                    else:
                        new_lines.append(line)
                else:
                    new_lines.append(line)
            with open(self.config_path, 'w') as f:
                f.writelines(new_lines)
            self.show_save_success()
        except PermissionError:
            self.show_error_dialog("Permission Denied", "Cannot write to config file.")
        except Exception as e:
            self.show_error_dialog("Error", f"Failed to save config: {str(e)}")

    def show_save_success(self):
        original_label = self.save_btn.get_label()
        self.save_btn.set_label("Saved!")
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(b"button { background: #4caf50; color: white; }")
        context = self.save_btn.get_style_context()
        context.add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)
        def reset_button():
            self.save_btn.set_label(original_label)
            context.remove_provider(css_provider)
            return False
        GLib.timeout_add(1500, reset_button)

    def show_reload_success(self):
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(b"button { background: #2196f3; color: white; }")
        context = self.reload_btn.get_style_context()
        context.add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)
        def reset_button():
            context.remove_provider(css_provider)
            return False
        GLib.timeout_add(1000, reset_button)

    def on_reload_clicked(self, button):
        self.load_config()
        self.show_reload_success()

    def on_save_clicked(self, button):
        self.save_config()

    def show_error_dialog(self, title, message):
        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=title,
        )
        dialog.format_secondary_text(message)
        dialog.run()
        dialog.destroy()

def main():
    os.environ['GDK_RENDERING'] = 'gl'
    os.environ['GSK_RENDERER'] = 'gl'
    os.environ['GDK_GL'] = '1'
    settings = Gtk.Settings.get_default()
    settings.set_property("gtk-application-prefer-dark-theme", True)
    settings.set_property("gtk-theme-name", "Adwaita-dark")
    settings.set_property("gtk-decoration-layout", "menu:minimize,maximize,close")
    win = ConfigEditor()
    if win.config_path:
        win.connect("destroy", Gtk.main_quit)
        win.show_all()
        Gtk.main()

if __name__ == "__main__":
    main()
