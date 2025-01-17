/* Copyright (c) 2015-2018 elementary LLC <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation, Inc.,; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
* Boston, MA 02110-1335 USA.
*/

namespace Marlin.View.Chrome {
    public class BreadcrumbIconInfo {
        public string path;
        public bool protocol;
        public GLib.Icon gicon;
        public string[] exploded;
        public bool break_loop;
        public string? text_displayed;
        public int icon_width;
        public int icon_height;

        public BreadcrumbIconInfo.special_directory (string path, string icon_name) {
            set_path (path);
            protocol = false;
            gicon = new GLib.ThemedIcon (icon_name);
            break_loop = false;
            text_displayed = Filename.display_basename (path);
        }

        public BreadcrumbIconInfo.protocol_directory (string scheme, string icon_name, string display_name) {
            path = scheme;
            protocol = true;
            gicon = new GLib.ThemedIcon (icon_name);
            break_loop = true;
            text_displayed = display_name;
        }

        public BreadcrumbIconInfo.from_mount (GLib.Mount mount) {
            GLib.File root = mount.get_root ();
            set_path (root.get_path ());
            protocol = false;
            gicon = mount.get_icon ();
            break_loop = true;
            text_displayed = mount.get_name ();
        }

        public Gdk.Pixbuf? render_icon (Gtk.StyleContext context) {
            var theme = Gtk.IconTheme.get_default ();
            Gdk.Pixbuf? icon = null;
            Gtk.IconInfo? gtk_icon_info = null;
            var scale = context.get_scale ();

            if (gicon == null) {
                gicon = new ThemedIcon.with_default_fallbacks ("image-missing");
            }

            var flags = Gtk.IconLookupFlags.FORCE_SIZE | Gtk.IconLookupFlags.FORCE_SYMBOLIC;
            gtk_icon_info = theme.lookup_by_gicon_for_scale (gicon, 16, scale, flags);

            if (gtk_icon_info != null) {
                try {
                    icon = gtk_icon_info.load_symbolic_for_context (context);
                    icon_width = icon.get_width () / scale;
                    icon_height = icon.get_height () / scale;
                } catch (Error e) {
                    warning ("Filed to load icon for %s - %s", text_displayed, e.message);
                }
            }

            return icon;
        }

        public void set_path (string path) {
            this.path = path;
            if (path != null) { /* We deal with path = "\" */
                if (path == Path.DIR_SEPARATOR_S) {
                    exploded = { Path.DIR_SEPARATOR_S };
                } else {
                    exploded = path.split (Path.DIR_SEPARATOR_S);
                    exploded[0] = Path.DIR_SEPARATOR_S;
                }
            }
        }
    }

    public class BreadcrumbIconList : Object {
        private Gee.ArrayList<BreadcrumbIconInfo> icon_info_list;
        public unowned Gtk.StyleContext context { get; construct; }

        public BreadcrumbIconList (Gtk.StyleContext context) {
            Object (context: context);
        }

        public int scale {
            get {
                return context.get_scale ();
            }
            set {
                context.set_scale (value);
            }
        }

        construct {
            icon_info_list = new Gee.ArrayList<BreadcrumbIconInfo> ();

            add_protocol_directory ("afp", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC);
            add_protocol_directory ("dav", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC);
            add_protocol_directory ("davs", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC);
            add_protocol_directory ("ftp", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC);
            add_protocol_directory ("sftp", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC);
            add_protocol_directory ("mtp", Marlin.ICON_DEVICE_REMOVABLE_MEDIA_SYMBOLIC);
            add_protocol_directory ("gphoto2", Marlin.ICON_DEVICE_CAMERA_SYMBOLIC);
            add_protocol_directory ("afc", Marlin.ICON_DEVICE_PHONE_SYMBOLIC);
            add_protocol_directory ("network", Marlin.ICON_NETWORK_SYMBOLIC);
            add_protocol_directory ("smb", Marlin.ICON_NETWORK_SERVER_SYMBOLIC);
            add_protocol_directory ("trash", Marlin.ICON_TRASH_SYMBOLIC);
            add_protocol_directory ("recent", Marlin.ICON_RECENT_SYMBOLIC);

            add_special_directory (Environment.get_user_special_dir (UserDirectory.MUSIC),
                                   Marlin.ICON_FOLDER_MUSIC_SYMBOLIC);
            add_special_directory (Environment.get_user_special_dir (UserDirectory.PICTURES),
                                   Marlin.ICON_FOLDER_PICTURES_SYMBOLIC);
            add_special_directory (Environment.get_user_special_dir (UserDirectory.VIDEOS),
                                   Marlin.ICON_FOLDER_VIDEOS_SYMBOLIC);
            add_special_directory (Environment.get_user_special_dir (UserDirectory.DOWNLOAD),
                                   Marlin.ICON_FOLDER_DOWNLOADS_SYMBOLIC);
            add_special_directory (Environment.get_user_special_dir (UserDirectory.DOCUMENTS),
                                   Marlin.ICON_FOLDER_DOCUMENTS_SYMBOLIC);
            add_special_directory (Environment.get_user_special_dir (UserDirectory.TEMPLATES),
                                   Marlin.ICON_FOLDER_TEMPLATES_SYMBOLIC);
            add_special_directory (PF.UserUtils.get_real_user_home (), Marlin.ICON_GO_HOME_SYMBOLIC, true);
            add_special_directory ("/media", Marlin.ICON_FILESYSTEM_SYMBOLIC, true);
            add_special_directory (Path.DIR_SEPARATOR_S, Marlin.ICON_FILESYSTEM_SYMBOLIC);
        }

        private void add_protocol_directory (string protocol, string icon) {
            var separator = "://" + ((protocol == "mtp" || protocol == "gphoto2") ? "[" : "");
            var info = new BreadcrumbIconInfo.protocol_directory (protocol + separator,
                                                                    icon,
                                                                    protocol_to_name (protocol));
            icon_info_list.add (info);
        }

        private void add_special_directory (string? dir, string icon_name, bool break_loop = false) {
            if (dir != null) {
                var icon = new BreadcrumbIconInfo.special_directory (dir, icon_name) {
                    break_loop = break_loop
                };

                icon_info_list.add (icon);
            }
        }

        public void add_mounted_volumes () {
            context.save ();
            context.set_state (Gtk.StateFlags.NORMAL);

            /* Add every mounted volume in our BreadcrumbIcon in order to load them properly in the pathbar if needed */
            var volume_monitor = VolumeMonitor.get ();
            GLib.List<GLib.Mount> mount_list = volume_monitor.get_mounts ();

            mount_list.foreach ((mount) => {
                var icon_info = new BreadcrumbIconInfo.from_mount (mount);
                if (icon_info.path != null) {
                    icon_info_list.add (icon_info);
                }
            });

            context.restore ();
        }

        public void truncate_to_length (int new_length) {
            for (int i = icon_info_list.size - 1; i >= new_length; i--) {
                icon_info_list.remove_at (i);
            }
        }

        public int length () {
            return icon_info_list.size;
        }

        public unowned Gee.ArrayList<BreadcrumbIconInfo> get_list () {
            return icon_info_list;
        }
    }
}
