import Toybox.Application;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.WatchUi;

// On-watch picker for the two user-configurable complication slots
// (complication1Label / complication2Label). Launched from a configurable
// press region via Segment34Delegate.handlePress when cID == -4.
//
// Root menu lists slot 1 and slot 2 with the current selection as a sub-label.
// Selecting a slot pushes a list of every complication enumerated via
// Complications.getComplications() — the same labels the Garmin complications
// picker shows. Selecting one writes the label to Application.Properties and
// pops back to the watch face.

(:background_excluded)
class ComplicationRootMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.menu_title_complications) as String });
        rebuild();
    }

    function rebuild() as Void {
        // Menu2 has no removeAll() across API levels — rebuild on each push instead.
        var label1 = Application.Properties.getValue("complication1Label") as String;
        var label2 = Application.Properties.getValue("complication2Label") as String;
        var none = WatchUi.loadResource(Rez.Strings.menu_item_none) as String;
        var slot1Title = WatchUi.loadResource(Rez.Strings.menu_item_slot_1) as String;
        var slot2Title = WatchUi.loadResource(Rez.Strings.menu_item_slot_2) as String;
        addItem(new WatchUi.MenuItem(
            slot1Title,
            (label1 != null && label1.length() > 0) ? label1 : none,
            0,
            null
        ));
        addItem(new WatchUi.MenuItem(
            slot2Title,
            (label2 != null && label2.length() > 0) ? label2 : none,
            1,
            null
        ));
    }
}

(:background_excluded)
class ComplicationRootDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _view as Segment34View;

    function initialize(view as Segment34View) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var slot = item.getId() as Number;
        WatchUi.pushView(
            new ComplicationListMenu(slot),
            new ComplicationListDelegate(slot, _view),
            WatchUi.SLIDE_LEFT
        );
    }
}

(:background_excluded)
class ComplicationListMenu extends WatchUi.Menu2 {
    function initialize(slot as Number) {
        Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.menu_title_choose_complication) as String });

        // First entry: clear the slot.
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.menu_item_none) as String,
            null,
            "",
            null
        ));

        try {
            var iter = Complications.getComplications();
            var comp = iter.next();
            while (comp != null) {
                var shortL = comp.shortLabel;
                var longL = comp.longLabel;
                var id = (shortL != null && shortL.length() > 0)
                            ? shortL
                            : ((longL != null && longL.length() > 0) ? longL : null);
                if (id != null) {
                    addItem(new WatchUi.MenuItem(
                        id,
                        longL != null && !longL.equals(id) ? longL : null,
                        id,
                        null
                    ));
                }
                comp = iter.next();
            }
        } catch (e) {}
    }
}

(:background_excluded)
class ComplicationListDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _slot as Number;
    hidden var _view as Segment34View;

    function initialize(slot as Number, view as Segment34View) {
        Menu2InputDelegate.initialize();
        _slot = slot;
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var label = item.getId() as String;
        var key = (_slot == 0) ? "complication1Label" : "complication2Label";
        Application.Properties.setValue(key, label);
        _view.onSettingsChanged();
        // Pop the list, then pop the root menu, back to the watch face.
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
