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
	return application.run(cast(string[])args);
}

extern(C) nothrow static int threadIdleProcess(void* data) {
	//Don't let D exceptions get thrown from this function
	try {
		import std.concurrency;
		import std.variant : Variant;
		import std.datetime;
		// get messages from parent thread
		receiveTimeout(dur!"usecs"(50_000),(int i) { 
					//Gui gui = cast(Gui)data;
					//foreach(gui; gui_windows) {
					//	gui.updateSession();
					//}
				}
			);
		//import core.thread;
		//Thread.sleep( dur!("msecs")( 50 ) );
		static int second_cnt = 0;
		static int cnt = 0;
		++second_cnt;
		if (second_cnt == 20) {
			import std.stdio;
			writeln("thisTid: ",thisTid," tick",++cnt,"\r");
			second_cnt = 0;
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

		import gtk.Box;
		auto main_box = new Box(GtkOrientation.HORIZONTAL,0);
		auto controlpanel_box = build_controlpanel();
		main_box.add(controlpanel_box);
		auto plotarea_box = build_plotarea(_sessionTid, in_other_thread, mode2d);
		main_box.add(plotarea_box);
		main_box.setChildPacking(plotarea_box,true,true,0,GtkPackType.START);

		add(main_box);
		showAll();
	}	

	

private:
	Tid _sessionTid;	
	Application _application;

}

auto build_controlpanel()
{
	import gtk.Box;
	import gtk.Button;

	auto box = new Box(GtkOrientation.VERTICAL,0);	

	auto button_hello = new Button("hello");
	void say_hello(Button button) {
		import std.stdio;
		writeln("hello button_clicked ", button.getLabel(), "\r");
	}
	button_hello.addOnClicked(button => say_hello(button)); 
	box.add(button_hello);

	auto button_bye = new Button("bye");
	void say_bye(Button button) {
		import std.stdio;
		writeln("bye button_clicked ", button.getLabel(), "\r");
	}
	button_bye.addOnClicked(button => say_bye(button)); 
	box.add(button_bye);

	return box;
}

auto build_plotarea(Tid sessionTid, bool in_other_thread, bool mode2d)
{
	import plotarea;
	import gtk.Box;

	auto box = new Box(GtkOrientation.HORIZONTAL,0);

	auto plot_area = new PlotArea(sessionTid, in_other_thread, mode2d);
	box.add(plot_area);
	box.setChildPacking(plot_area,true,true,0,GtkPackType.START);

	return box;
}

