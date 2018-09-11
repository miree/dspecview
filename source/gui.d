import std.concurrency;
void startgui(immutable string[] args, Tid sessionTid)
{
    run(args,sessionTid,false);
}
Tid startguithread(immutable string[] args, Tid sessionTid)
{
	import std.concurrency;
    return spawn(&threadfunction, args, sessionTid);
}
void threadfunction(immutable string[] args, Tid sessionTid)
{
	// last parameter tells the gui that it runs in a separate thread. This is 
	// important because memory handling is different in this case and memory
	// leaks if that is not handled explicitely
    run(args, sessionTid, true);
}


import gio.Application : GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;
int run(immutable string[] args, Tid sessionTid, bool in_other_thread = false)
{
	import std.concurrency;
	import gdk.Threads;
	auto application = new Application("de.egelsbach.dspecview", GApplicationFlags.FLAGS_NONE);
	application.addOnActivate(delegate void(GioApplication app) { 
			auto gui = new Gui(application, sessionTid, in_other_thread); 
			gdk.Threads.threadsAddIdle(&threadIdleProcess, cast(void*)gui);
		});
	auto result = application.run(cast(string[])args);

	return result;
}



extern(C) nothrow static int threadIdleProcess(void* data) {
	//Don't let D exceptions get thrown from this function
	try {

		Gui gui = cast(Gui)data;
		gui.message_handler();

		//import core.thread;
		//Thread.sleep( dur!("msecs")( 50 ) );
		static int second_cnt = 0;
		static int cnt = 0;
		++second_cnt;
		if (second_cnt == 100) {
			import std.stdio;
			//writeln("thisTid: ",thisTid," tick",++cnt,"\r");
			second_cnt = 0;
			gui.second_handler();
			// now do the "per second" business
			//Gui gui = cast(Gui)data;
			//foreach(gui; gui_windows){
			//	gui.updateSession();
			//	gui._plot_area.refresh();
			//	gui._plot_area.queueDraw();
			//}
		}
	} catch (Throwable t) {
		return 0;
	}
	return 1;
}



class Gui : ApplicationWindow
{
public:
	import std.concurrency;

	this(Application application, 
		 Tid         sessionTid, 
		 bool        in_other_thread, 
		 bool        controlpanel = true,
		 bool        plotarea     = false,
		 bool        mode2d       = false)
	{
		super(application);
		_application = application;

		_sessionTid  = sessionTid;

		// main layout is:
		// control bar on the left hand side, plot area on the right hand side
		// both sides are organized inside of the main_box
		import gtk.Box;
		auto main_box = new Box(GtkOrientation.HORIZONTAL,0);

		// add the control panel
		_control_panel = new ControlPanel(sessionTid, this);
		main_box.add(_control_panel);

		// add the plot area

		_visualization = new Visualization(sessionTid, in_other_thread, mode2d);
		main_box.add(_visualization);
		main_box.setChildPacking(_visualization,true,true,0,GtkPackType.START);



		// define some hotkeys
		import gtk.Widget;
		addOnKeyPress(delegate bool(GdkEventKey* e, Widget w) { // the action to perform if that menu entry is selected
							//writeln("key press: ", e.keyval, "\r");
							switch(e.keyval) {
								case 'f': _visualization.setFit();             break;
								case 'z': _visualization.toggle_autoscale_z(); break;
								case 'y': _visualization.toggle_autoscale_y(); break;
								case 'x': _visualization.toggle_autoscale_x(); break;
								case 'l': _visualization.toggle_logscale();    break;
								case 'o': _visualization.toggle_overlay();     break;
								default:
							}
							return true;
						});

		setTitle("gtkD Spectrum Viewer");
		setDefaultSize( 300, 300 );



		//auto plotarea_box = build_plotarea(_sessionTid, in_other_thread, mode2d);
		//main_box.add(plotarea_box);

		add(main_box);
		showAll();
	}	


	void add_visualize(string intemname) 
	{

	}

	void redraw_content()
	{
		_visualization.redraw_content();
	}

	void second_handler()
	{
		if (_visualization.autoRefresh()) {
			_visualization.refresh();
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
				_control_panel.refresh();
			},
			(MsgItemList itemlist) {
				_control_panel.updateTreeStoreFromSession(itemlist);
			},
			(MsgVisualizeItem msg, immutable(Visualizer) visualizer) {
				import std.stdio;
				_visualization.add(msg.itemname, visualizer);
			},
			(MsgRemoveVisualizedItem msg) {
				_visualization.remove(msg.itemname);
				_visualization.redraw_content();
			},
			//(string message) {
			//	import std.stdio;
			//	writeln(message,"\r");
			//},
			(MsgRedrawContent redraw) {
				_visualization.redraw_content();
			},
			(MsgFitContent fit) {
				_visualization.setFit();
			}
		);
	}

private:
	Tid _sessionTid;
	Application _application;

	import gui_controlpanel, gui_visualization;
	ControlPanel _control_panel;
	Visualization _visualization;
}


// messages for the gui
struct MsgVisualizeItem {
	string itemname;
}
struct MsgRemoveVisualizedItem {
	string itemname;
}
struct MsgRefreshItemList {
}
struct MsgRedrawContent {
}
struct MsgFitContent {
}








