import std.concurrency;
void startgui(immutable string[] args, Tid sessionTid, string window_title)
{
    run(args, sessionTid, window_title, false);
}
Tid startguithread(immutable string[] args, Tid sessionTid, string window_title)
{
	import std.concurrency;
    return spawn(&threadfunction, args, sessionTid, window_title);
}
void threadfunction(immutable string[] args, Tid sessionTid, string window_title)
{
	// last parameter tells the gui that it runs in a separate thread. This is 
	// important because memory handling is different in this case and memory
	// leaks if that is not handled explicitely
    run(args, sessionTid, window_title, true);
}

import gio.Application : GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;
Application application;
int run(immutable string[] args, Tid sessionTid, string window_title, bool in_other_thread = false)
{
	import std.concurrency;
	import gdk.Threads;
	application = new Application("de.egelsbach.dspecview", GApplicationFlags.FLAGS_NONE);
	application.addOnActivate(delegate void(GioApplication app) { 
			auto gui = new Gui(application, sessionTid, in_other_thread, window_title); 
			gdk.Threads.threadsAddIdle(&threadIdleProcess, cast(void*)gui);
		});
	auto result = application.run(cast(string[])args);

	import std.stdio;
	return result;
}

public immutable string guiNamePrefix = "GUIwindows/";
immutable string baseTitle = "GtkD Spectrum Viewer";

Gui[ulong] guis;
bool application_running = false;
ulong gui_counter = 0;
extern(C) nothrow static int threadIdleProcess(void* data) {
	//Don't let D exceptions get thrown from this function
	try {

		//Gui gui = cast(Gui)data;
		foreach(gui; guis) {
			gui.message_handler();
		}

		import core.thread;
		//Thread.sleep( dur!("msecs")( 50 ) );
		static int second_cnt = 0;
		static int cnt = 0;
		++second_cnt;
		if (second_cnt == 10) {
			// now do the "per second" business
			import std.stdio;
			second_cnt = 0;
			foreach(gui; guis) {
				gui.second_handler();
			}
		}

		if (!application_running) {
			return 0;
		}

	} catch (Throwable t) {
		import std.stdio;
		try {
			writeln("exceptions in threadIdleProcess", t.msg, "\r");
			} catch (Throwable t) {
				// nothing
			}
	}
	return 1;
}

	import gtk.Popover, gtk.Widget;
    Popover createPopover(Widget parent) {
		import gio.Menu : GMenu = Menu;
		import gio.MenuItem : GMenuItem = MenuItem;
        GMenu model = new GMenu();

        GMenu mFileSection = new GMenu();
        mFileSection.appendItem(new GMenuItem("Open…", null));
        mFileSection.appendItem(new GMenuItem("Save", null));
        mFileSection.appendItem(new GMenuItem("Save As…", null));
        mFileSection.appendItem(new GMenuItem("Close", null));
        model.appendSection(null, mFileSection);

        //GMenu mSessionSection = new GMenu();
        //mSessionSection.appendItem(new GMenuItem(_("Name…"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_NAME)));
        //mSessionSection.appendItem(new GMenuItem(_("Synchronize Input"), getActionDetailedName(ACTION_PREFIX, ACTION_SESSION_SYNC_INPUT)));
        //model.appendSection(null, mSessionSection);

        //if (isQuake()) {
        //    GMenu mPrefSection = new GMenu();
        //    mPrefSection.appendItem(new GMenuItem(_("Preferences"), getActionDetailedName("app", "preferences")));
        //    model.appendSection(null, mPrefSection);
        //}

        //debug(GC) {
        //    GMenu mDebugSection = new GMenu();
        //    mDebugSection.appendItem(new GMenuItem(_("GC"), getActionDetailedName("win", "gc")));
        //    model.appendSection(null, mDebugSection);
        //}

        return new Popover(parent, model);
    }

class Gui : ApplicationWindow
{
public:
	import std.concurrency;


	this(Application application, 
		 Tid         sessionTid, 
		 bool        in_other_thread, 
		 string      title = null,
		 bool        controlpanel = true,
		 bool        plotarea     = true,
		 bool        mode2d       = false)
	{
		super(application);
		application_running = true;
		_application = application;
		_sessionTid  = sessionTid;
		_in_other_thread = in_other_thread;
		_mode2d = mode2d;


		_gui_idx = gui_counter++;
		guis[_gui_idx] = this;

		import std.stdio;
		//writeln("new Gui with _gui_idx=", _gui_idx,"\r");
		// main layout is:
		// control bar on the left hand side, plot area on the right hand side
		// both sides are organized inside of the _main_box
		import gtk.Box;

		_vbox = new Box(GtkOrientation.VERTICAL,0);
		_hbar = new HeaderBar();


        ////Session Actions
        //import gtk.Image, gtk.MenuButton;
        //auto mb = new MenuButton();
        //mb.setFocusOnClick(false);
        //Image iHamburger = new Image("open-menu-symbolic", IconSize.MENU);
        //mb.add(iHamburger);
        //mb.setPopover(createPopover(mb));

        //_hbar.packStart(mb);


        import gtk.Button, gtk.Image;
		auto button_newwindow = new Button();//"new\nwin");
		Image iAdd = new Image(StockID.ADD, IconSize.MENU);
		button_newwindow.add(iAdd);
		void create_new_window(Button button) {
			//import std.stdio;
			//writeln("hello button_clicked ", button.getLabel(), "\r");
			auto gui = new Gui(getApplication(), _sessionTid, getInOtherThread(), null, true , true); 
		}
		button_newwindow.addOnClicked(button => create_new_window(button)); 
		_hbar.packEnd(button_newwindow);

		auto button_open = new Button();//"open");
		Image iOpen = new Image(StockID.OPEN, IconSize.MENU);
		button_open.add(iOpen);
		void f_button_open(Button button) {
			import multi_file_chooser;
			string[] result;
			auto child_window = new MultiFileChooser(getApplication(), _sessionTid);
		}
		button_open.addOnClicked(button => f_button_open(button)); 
		_hbar.add(button_open);

		auto button_refresh = new Button();//"refresh");
		button_refresh.add(new Image(StockID.REFRESH, IconSize.MENU));
		void f_button_refresh(Button button) {
			_control_panel.refresh();
		}
		button_refresh.addOnClicked(button => f_button_refresh(button)); 
		_hbar.add(button_refresh);


		auto button_toggle_visualizer = new Button();//"toggle\nvisualizer");
		auto button_toggle_visualizer_image = new Image(StockID.CLEAR, IconSize.MENU);
		button_toggle_visualizer.setImage(button_toggle_visualizer_image);
		void f_button_toggle_visualizer(ref Button button) {
			toggleVisualizer();
			if (_visualization is null) { 
				button.setImage(new Image(StockID.ZOOM_FIT, IconSize.MENU));
			} else {
				button.setImage(new Image(StockID.CLEAR, IconSize.MENU));
			}
		}
		button_toggle_visualizer.addOnClicked(button => f_button_toggle_visualizer(button)); 
		_hbar.add(button_toggle_visualizer);



		_main_box = new Box(GtkOrientation.HORIZONTAL,0);

		import gdk.Event;
		import gtk.Widget;
		_main_box.addOnDestroy(delegate( Widget w) { 
				import std.stdio;
				guis.remove(_gui_idx);
				if (guis.length == 0) {
					application_running = false;
					import session;
					_sessionTid.send(MsgGuiQuit());
				}
				_sessionTid.send(MsgRemoveItem(guiName), thisTid);
			});

		// add the control panel
		if (controlpanel) {
			_control_panel = new ControlPanel(sessionTid, this);
			_main_box.add(_control_panel);
			if (!plotarea) {
				_main_box.setChildPacking(_control_panel,true,true,0,GtkPackType.START);
			}
		}

		// add the plot area

		if (plotarea) {
			_visualization = new Visualization(sessionTid, in_other_thread, mode2d, this);
			_main_box.add(_visualization);
			_main_box.setChildPacking(_visualization,true,true,0,GtkPackType.START);



			// define some hotkeys
			import gtk.Widget;
			addOnKeyPress(delegate bool(GdkEventKey* e, Widget w) { // the action to perform if that menu entry is selected
								//writeln("key press: ", e.keyval, "\r");
								if (_visualization !is null) {
									switch(e.keyval) {
										case 'f': _visualization.setFit();             break;
										case 'z': _visualization.toggle_autoscale_z(); break;
										case 'y': _visualization.toggle_autoscale_y(); break;
										case 'x': _visualization.toggle_autoscale_x(); break;
										case 'l': _visualization.toggle_logscale();    break;
										case 'o': _visualization.toggle_overlay();     break;
										default:
									}
								}
								return true;
							});
		}

		import std.conv;
		if (title is null)  {
			title = "window" ~ _gui_idx.to!string;
		}

		_hbar.setTitle (title);
		_hbar.setSubtitle (baseTitle);
		newTitle(title);

		setDefaultSize( 300, 300 );

		_vbox.add(_hbar);
		_vbox.add(_main_box);
		_vbox.setChildPacking(_main_box,true,true,0,GtkPackType.START);

		add(_vbox);
		showAll();

		import std.stdio;


		_sessionTid.send(MsgAddGuiItem(guiName(),_gui_idx), thisTid);

		// get up to date with the session data
		import session;
		_sessionTid.send(MsgGuiStarted(), thisTid);
		_sessionTid.send(MsgRequestItemList(), thisTid);

	}

	void newTitle(string title)
	{
		setTitle(baseTitle ~ " -- " ~ title);
	}

	string guiName() {
		import std.conv;
		return guiNamePrefix ~ "window" ~ _gui_idx.to!string;
	}

	void toggleVisualizer() {
		if (_visualization !is null) {
			_visualization.destroy();
			_visualization = null;
			_main_box.setChildPacking(_control_panel,true,true,0,GtkPackType.START);
		} else {

			_visualization = new Visualization(_sessionTid, _in_other_thread, _mode2d, this);
			_main_box.add(_visualization);
			_main_box.setChildPacking(_visualization,true,true,0,GtkPackType.START);
			_main_box.setChildPacking(_control_panel,false,false,0,GtkPackType.START);
			showAll();
		}
	}

	ulong getGuiIdx() {
		return _gui_idx;
	}

	bool getInOtherThread() {
		return _in_other_thread;
	}

	void add_visualize(string intemname) 
	{

	}

	void redraw_content()
	{
		if (_visualization !is null) {
			_visualization.redraw_content();
		}
	}

	void second_handler()
	{
		foreach (gui; guis) {
			if (gui._visualization !is null) {
				if (gui._visualization.autoRefresh()) {
					gui._visualization.refresh();
				}
			}
		}
	}


void message_handler()
{
	import std.concurrency;
	import std.variant : Variant;
	import std.datetime;

	import session;

	// get messages from other threads
	receiveTimeout(dur!"usecs"(1_000),
		(MsgRefreshItemList refresh_list) {
			foreach(gui; guis) {
				if (gui !is null) {
					if (gui._control_panel !is null ) {
						gui._control_panel.refresh();
					}
				}
			}
		},
		(MsgItemList itemlist) {
			foreach(gui; guis) {
				if (gui !is null) {
					if (gui._control_panel !is null ) {
						gui._control_panel.updateTreeStoreFromSession(itemlist);
					}
				}
			}
		},
		(MsgVisualizeItem msg, immutable(Visualizer) visualizer) {
			import std.stdio;
			//writeln("gui: got visualizer for item: ", msg.itemname, "\r");
			if (visualizer !is null) {
				//writeln("gui[",msg.gui_idx,"]: add visualizer \r");
				auto gui = guis[msg.gui_idx];
				if (gui !is null) {
					if (gui._visualization !is null ) {
						guis[msg.gui_idx]._visualization.addVisualizer(msg.itemname, visualizer);
					}
				}
			}
		},
		(MsgRemoveVisualizedItem msg) {
			foreach(gui; guis) {
				if (gui._visualization !is null ) {
					gui._visualization.remove(msg.itemname);
					gui._visualization.redraw_content();
				}
			}
		},
		(MsgRedrawContent redraw) {
			if (guis[redraw.gui_idx]._visualization !is null) {
				guis[redraw.gui_idx]._visualization.redraw_content();
			}
		},
		(MsgFitContent fit) {
			if (guis[fit.gui_idx]._visualization !is null) {
				guis[fit.gui_idx]._visualization.setFit();
			}
		},
		(MsgCloseWindow close) {
			if (guis[close.gui_idx] !is null) {
				guis[close.gui_idx].destroy();
			}
		},
		(MsgNewWindow newwindow) {
			new Gui(getApplication(), _sessionTid, getInOtherThread(), newwindow.title, true , true); 
		},
		(MsgVisuWindowSettings settings) {

		}
	);
}


private:
	Tid _sessionTid;
	Application _application;
	bool _mode2d;


	import gtk.HeaderBar;
	HeaderBar _hbar;

	import gtk.Box;
	Box _main_box; // contains all interactive gui elements
	Box _vbox;     // contains the header bar (_hbar) and the _main_box

	import gui_controlpanel, gui_visualization;
	ControlPanel _control_panel;
	Visualization _visualization;

	bool _in_other_thread;
	ulong _gui_idx;
}


// messages for the gui
struct MsgVisualizeItem {
	string itemname;
	ulong gui_idx;
}
struct MsgRemoveVisualizedItem {
	string itemname;
}
struct MsgRefreshItemList {
}
struct MsgRedrawContent {
	ulong gui_idx;
}
struct MsgFitContent {
	ulong gui_idx;
}
struct MsgCloseWindow {
	ulong gui_idx;
}
struct MsgNewWindow {
	string title;
}
struct MsgVisuWindowSettings {
	bool autoRefresh;
	bool overview;
	bool autoscaleX, autoscaleY, autoscaleZ;
	bool logX, logY, logZ;
	bool gridX, gridY, gridTop;
	bool overlay;
	bool row_major;
	uint columns_or_rows;
}


///////////////////////////////////////////////////////////////
// make an item that represents a Gui window
import session;
class GuiItem : Item 
{
public:
	this(string name, ulong gui_idx) {
		_name = name;
		_gui_idx = gui_idx;
	}

	string getTypeString() {
		return "GUI window";
	}

	ulong guiIdx() {
		return _gui_idx;
	}

	override immutable(GuiVisualizer) createVisualizer() 
	{
		import std.conv;
		return new immutable(GuiVisualizer)(_name);
	}
private:
	string _name;
	ulong _gui_idx;
}

immutable class GuiVisualizer : Visualizer 
{
	import cairo.Context, cairo.Surface;
	import view;
	this(string name) {
		_name = name;
	}
	override string getItemName() immutable {
		return _name;
	}
	override ulong getDim() immutable {
		return 1;
	}
	override void print(int context) immutable {
		import std.stdio;
		writeln(_name,"\r");
	}
	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz) immutable {
		return;
	}
	override bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable {
		return false;
	}
	override bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable 
	{
		return false;
	}
	override bool getZminZmaxInLeftRightBottomTop(out double mi, out double ma, 
	                                     double left, double right, double bottom, double top, 
	                                     bool logz, bool logy, bool logx) immutable
	{
		return false;
	}

private:
	string _name;
}


