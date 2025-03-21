/* LanguageFilter.vala
 *
 * Copyright (C) 2009-2025 Jerry Casiano
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.
 *
 * If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>.
*/

internal const string SELECT_ON_LANGUAGE = """
SELECT DISTINCT Fonts.family, Fonts.description
FROM Fonts, json_tree(Orthography.support, '$.%s')
JOIN Orthography USING (filepath, findex)
WHERE json_tree.key = 'coverage' AND json_tree.value > %f;
""";

const string DEFAULT_LANGUAGE_FILTER_COMMENT = _("Filter based on supported orthographies");

namespace FontManager {

    public class LanguageFilter : Category {

        public double coverage { get; set; default = 90; }
        public StringSet selections { get; set; default = new StringSet(); }

        public LanguageFilterSettings settings {
            get {
                if (filter_settings != null)
                    return filter_settings;
                filter_settings = new LanguageFilterSettings();
                BindingFlags flags = BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE;
                bind_property("coverage", settings, "coverage", flags);
                bind_property("selections", settings, "selections", flags);
                filter_settings.update();
                filter_settings.changed.connect(on_change);
                return filter_settings;
            }
        }

        GLib.Settings? gsettings = null;
        LanguageFilterSettings? filter_settings = null;

        public LanguageFilter () {
            base(_("Supported Orthographies"),
                 DEFAULT_LANGUAGE_FILTER_COMMENT,
                 "preferences-desktop-locale-symbolic",
                 SELECT_ON_LANGUAGE,
                 CategoryIndex.LANGUAGE);
            // XXX : Here for testing purposes? or for good?
            gsettings = get_gsettings(BUS_ID);
            restore_state(gsettings);
            selections.changed.connect_after(on_change);
        }

        void on_change () {
            save_state(gsettings);
            update.begin((obj, res) => {
                update.end(res);
                changed();
            });
            return;
        }

        public void restore_state (GLib.Settings settings) {
            foreach (var entry in settings.get_strv("language-filter-list"))
                selections.add(entry);
            coverage = settings.get_double("language-filter-min-coverage");
            update.begin();
            return;
        }

        public void save_state (GLib.Settings settings) {
            settings.set_strv("language-filter-list", selections.to_strv());
            settings.set_double("language-filter-min-coverage", coverage);
            return;
        }

        public override async void update () {
            families.clear();
            variations.clear();
            try {
                Database db = DatabaseProxy.get_default_db();
                foreach (string language in selections) {
                    var pref_loc = Intl.setlocale(LocaleCategory.ALL, "");
                    Intl.setlocale(LocaleCategory.ALL, "C");
                    string _sql_ = sql.printf(language.replace("'", "''"), coverage);
                    Intl.setlocale(LocaleCategory.ALL, pref_loc);
                    get_matching_families_and_fonts(db, families, variations, _sql_);
                }
            } catch (Error e) {
                warning(e.message);
            }
            // Model update
            changed();
            return;
        }

    }

    public class LanguageListRow : ListItemRow {

        public signal void changed (LanguageListRow item);

        public bool active { get; set; default = false; }

        public string orthography { get; private set; }
        public string local_name { get; private set; }
        public string native_name { get; private set; }

        public class LanguageListRow (BaseOrthographyData data) {
            orthography = data.name;
            local_name = Markup.escape_text(dgettext(null, data.name));
            native_name = data.native;
            item_state.visible = true;
            item_label.set_label(native_name);
            item_label.ellipsize = Pango.EllipsizeMode.NONE;
            item_count.remove_css_class("count");
            item_count.add_css_class("dim-label");
            item_count.visible = true;
            item_count.sensitive = true;
            item_count.set_markup(@"<span size=\"x-small\" font=\"mono\">$local_name</span>");
            item_count.ellipsize = Pango.EllipsizeMode.MIDDLE;
            set_tooltip_text(local_name);
            BindingFlags flags = BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE;
            bind_property("active", item_state, "active", flags);
            item_state.toggled.connect(() => { changed(this); });
        }

    }

    [GtkTemplate (ui = "/com/github/FontManager/FontManager/ui/font-manager-language-filter-settings.ui")]
    public class LanguageFilterSettings : Gtk.Box {

        public signal void changed ();

        public double coverage { get; set; default = 90.0; }
        public StringSet selections { get; set; default = new StringSet(); }

        [GtkChild] public unowned Gtk.SearchBar search_bar { get; }
        [GtkChild] public unowned Gtk.SearchEntry search_entry { get; }

        [GtkChild] unowned Gtk.Button clear_button;
        [GtkChild] unowned Gtk.ListBox listbox;
        [GtkChild] unowned Gtk.SpinButton coverage_spin;

        public LanguageFilterSettings () {
            widget_set_name(this, "FontManagerLanguageFilterSettings");
            listbox.set_filter_func((Gtk.ListBoxFilterFunc) matches_search);
            listbox.set_selection_mode(Gtk.SelectionMode.NONE);
            BindingFlags flags = BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE;
            bind_property("coverage", coverage_spin, "value", flags);
            populate_list_box();
            clear_button.set_sensitive(selections.size > 0);
        }

        void on_item_changed (LanguageListRow item) {
            if (item.active)
                selections.add(item.orthography);
            else
                selections.remove(item.orthography);
            clear_button.set_sensitive(selections.size > 0);
            debug("LanguageFilterSettings : %s %s %s selected items",
                  item.orthography, item.active ? "added" : "removed",
                  item.active ? "to" : "from");
            return;
        }

        public void update () {
            int i = 0;
            Gtk.ListBoxRow? widget = listbox.get_row_at_index(i);
            while (widget != null) {
                var row = (LanguageListRow) widget.get_child();
                row.active = (row.orthography in selections);
                i++;
                widget = listbox.get_row_at_index(i);
            }
            return;
        }

        void populate_list_box () {
            foreach (var entry in Orthographies) {
                var item = new LanguageListRow(entry);
                listbox.append(item);
                item.active = (item.orthography in selections);
                item.changed.connect(on_item_changed);
            }
            return;
        }

        [CCode (instance_pos = -1)]
        // Necessary to generate valid C code for this function since self gets
        // passed as user_data argument in call to gtk_list_box_set_filter_func
        bool matches_search (Gtk.ListBoxRow list_box_row) {
            bool match = true;
            var search_term = search_entry.get_text().dup();
            if (search_term == null)
                return match;
            string needle = search_term.strip().casefold();
            if (needle.length < 1)
                return match;
            var row = (LanguageListRow) list_box_row.get_child();
            match = row.native_name.casefold().contains(needle);
            if (!match)
                match = row.local_name.casefold().contains(needle);
            return match;
        }

        [GtkCallback]
        void on_search_changed (Gtk.SearchEntry entry) {
            listbox.invalidate_filter();
            return;
        }

        [GtkCallback]
        void on_clear_button_clicked (Gtk.Button button) {
            int i = 0;
            Gtk.ListBoxRow? widget = listbox.get_row_at_index(i);
            while (widget != null) {
                var row = (LanguageListRow) widget.get_child();
                row.active = false;
                i++;
                widget = listbox.get_row_at_index(i);
            }
            return;
        }

        [GtkCallback]
        void on_coverage_changed () {
            changed();
            debug("%s::coverage : %0.1f", name, coverage);
            return;
        }

    }

}


