////////////////////////////////////////
// Interface for all items that are 
// handled by a session
interface Item
{
public:
	////////////////////////////////////////
	// Each Item knows how to create a
	// visualizer that can draw onto a 
	// cairo context
	immutable(Visualizer) createVisualizer();

	////////////////////////////////////////
	// Each Item knows what type it is 
	// the returned value will be shown in 
	// the tree view column "type"
	string getTypeString();

	int getColorIdx();
	void setColorIdx(int idx);	
}

immutable interface ItemFactory 
{
public: 
	Item getItem() pure;
}


////////////////////////////////////////
// Store information about mouse
// intercation with the item
struct ItemMouseAction {
	int idx = -1; // 
	bool relevant; // if true, this information can be used in the drawing process 
	double x_current,y_current;
	double x_start,y_start;
	bool button_down; // is true if the mouse button is down 
	string itemname;
	ulong gui_idx;
	bool dragging;
}


////////////////////////////////////////
// Visualizer contexts are hold together
// with an immutable Visuzlizer to hold
// some mutable context data that can
// be used by the Visualizer during
// rendering
class VisualizerContext {
	bool active;  // if context is active, the corresponding visualizer is skipped by plot area refresh 
	bool changed; // Visualizer has to set this to true if it wants a redraw
}
////////////////////////////////////////
// All objects that are created by items
// in order to draw have to implement
// this interface. Visualizer objects 
// are shared between theads and have 
// therefore to be immutable
immutable interface Visualizer 
{
public:
	import std.concurrency;
	import cairo.Context, cairo.Surface;
	import view;
	//string getItemName() immutable;
	int getColorIdx() immutable;
	ulong getDim() immutable;
	void print(int context) immutable;
	bool needsColorKey() immutable;
	void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz, ItemMouseAction mouse_action, VisualizerContext context) immutable;
	bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable;
	bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable;
	bool getZminZmaxInLeftRightBottomTop(out double mi, out double ma, 
	                                     double left, double right, double bottom, double top, 
	                                     bool logz, bool logy, bool logx) immutable;
	bool mouseDistance(out double dx, out double dy, double x, double y, bool logx, bool logy, VisualizerContext context) immutable;
	void mouseButtonDown(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable;
	void mouseDrag(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable;
	void mouseButtonUp(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable;
	VisualizerContext createContext() immutable;
}



immutable class BaseVisualizer : Visualizer 
{
public:
	import std.concurrency;
	import cairo.Context, cairo.Surface;
	import view;

	this(int colorIdx) {
		_colorIdx = colorIdx;
	}

	override int getColorIdx() immutable {
		return _colorIdx;
	}
	override ulong getDim() immutable {
		return 0; // means undecided (can live with 1d or 2d)
	}
	override void print(int context) immutable {
	}
	override bool needsColorKey() immutable {
		return false;
	}
	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz, ItemMouseAction mouse_action, VisualizerContext context) immutable {
	}
	override bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable
	{
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

	override bool mouseDistance(out double dx, out double dy, double x, double y, bool logx, bool logy, VisualizerContext context) immutable
	{
		return false;
	}
	override void mouseButtonDown(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
	}
	override void mouseDrag(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
	}
	override void mouseButtonUp(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
	}
	override VisualizerContext createContext() immutable
	{
		return new VisualizerContext();
	}


protected:
	int    _colorIdx;
}


////////////////////////////////////////
// Send this message if you want to test
// if the session is running and is 
// responsive
struct MsgSayHi {
	public string text;
}

////////////////////////////////////////
// Send this message if you want the 
// session to stop its main loop
struct MsgStop {	
}

////////////////////////////////////////
// Send this message if you want the 
// session to run its main loop
struct MsgRun {	
}

//struct MsgAddGuiItem{
//	string guiname;
//	ulong gui_idx;
//}

struct MsgRemoveItem{
	string itemname;
}

struct MsgAddItem{
	string itemname;
	immutable ItemFactory item_factory;
}



////////////////////////////////////////
// Write a list of items to terminal
struct MsgRequestItemList{
}
// response to the above request
struct MsgItemList { 
	string nametype; 
};
struct MsgRequestItemUpdate {
}
struct MsgUpdateItem { 
	string nametype; 
};

////////////////////////////////////////
// call the refresh function on an item
struct MsgRequestItemVisualizer {
	string itemname;
	ulong gui_idx;
	immutable(Visualizer) old_visualizer = null;
}

////////////////////////////////////////
// Request to get an echo on this 
// message. This is usefult if a 
// number of request was sent to
// the session, but responses are
// evaluated at a different part of 
// the asking thread. The echo message
// can be used to indicate the last 
// request was handled.
struct MsgEchoRedrawContent {
	ulong gui_idx;
}
struct MsgEchoFitContent {
	ulong gui_idx;
}

struct MsgGuiStarted {
}
struct MsgGuiQuit {
}
struct MsgIsGuiRunning {
}
struct MsgGuiRunningStatus {
	bool running;
}

class Session
{
public:
	bool run()
	{
		try {
		_running = true;

		////////////////////////////////////////
		// The main event loop. 
		// Messages send to this thread control 
		// the entire session.
		import std.concurrency;
		import std.variant : Variant;
		import std.datetime;
		import std.stdio;

		while (_running) {
			import std.stdio;
			//writeln("session: tick\r");
			//receiveTimeout(dur!"usecs"(500_000), // 500 ms
			receive(
				(MsgSayHi msg, Tid requestingThread) { 
					if (_output_all_messages) { writeln("got MsgSayHi\r"); }
					requestingThread.send("message to session was: " ~ msg.text);
				},
				(MsgStop stop, Tid requestingThread) {
					if (_output_all_messages) { writeln("got MsgStop\r"); }
					_running = false;
					requestingThread.send("session stopped");
				},
				(MsgRun run, Tid requestingThread) {
					if (_output_all_messages) { writeln("got MsgRun\r"); }
					requestingThread.send("session is already running");
				},
				(MsgRemoveItem msg, Tid requestingThread) {
					if (_output_all_messages) { writeln("got MsgRemoveItem\r"); }
					Item item = _items[msg.itemname];
					auto result = _items.remove(msg.itemname);
					if (result) {
						import std.stdio;
						//writeln("item ",msg.itemname," removed\r");
						if (_guiRunning) {
							import gui;
							_guiTid.send(MsgRefreshItemList());
							_guiTid.send(MsgRemoveVisualizedItem(msg.itemname));
						}
					} else {
						import std.stdio;
						//writeln("item ",msg.itemname," not found\r");
					}
				},
				(MsgAddItem msg) {
					if (_output_all_messages) { writeln("got MsgAddItem\r"); }
					try {
						string itemname = msg.itemname;

						auto item_ptr = itemname in _items;
						bool already_there = item_ptr !is null;

						_items[itemname] = msg.item_factory.getItem();
						if (_items[itemname].getColorIdx() < 0) {
							_items[itemname].setColorIdx(_colorIdx_counter++);
						}
						if (_guiRunning) {
							import gui;
							if (already_there) {
								import std.conv;
								_guiTid.send(MsgUpdateItem(itemname ~ "$" ~ _items[itemname].getTypeString() ~ "$" ~ _items[itemname].getColorIdx().to!string));
							} else {
								_guiTid.send(MsgRefreshItemList());
							}
						}
					} catch (Exception e) {
						//requestingThread.send(e.msg);
					}
				},
				(MsgRequestItemList msg, Tid requestingThread) {
					if (_output_all_messages) { writeln("got MsgRequestItemList\r"); }
					import textui;
					import std.stdio;
					//writeln("got request to send itemlist");
					if (_items.length == 0) {
						requestingThread.send(MsgItemList());
					} else {
						string itemlist; // will contains items separated by spaces (' ')
						foreach(itemname, item; _items) {
							import std.conv;
							itemlist ~= itemname ~ '$' ~ item.getTypeString() ~ '$' ~ item.getColorIdx().to!string ~ '|';
						}
						itemlist = itemlist[0..$-1]; // remove last ' '

						// send the resoponse
						requestingThread.send(MsgItemList(itemlist));
					}
				},
				(MsgRequestItemVisualizer msg, Tid requestingThread) {
					if (_output_all_messages) { writeln("got MsgRequestItemVisualizer\r"); }
					import std.stdio;
					auto item = msg.itemname in _items;
					if (item is null) {
						writeln("session: unknown item: ", msg.itemname, "\r");
						requestingThread.send("unknown item: " ~ msg.itemname);
					} else {
						import gui;
						//writeln("session: sending visualizer for: ", msg.itemname, "\r");
						try {
							auto visualizer = item.createVisualizer();
							// only send an updated visualizer if we have something to send
							// and if the sent visualizer is different from the previous one
							if (visualizer !is null && visualizer !is msg.old_visualizer) {
								//writeln("visualizer created\r");
								requestingThread.send(MsgVisualizeItem(msg.itemname, msg.gui_idx), visualizer);
							}
							//writeln("message sent\r");
						} catch (Exception e) {
							writeln("Exception while creating visualizer " ~ e.msg,"\r");
						}
						//writeln("session: sending visualizer done \r");
					}
				},
				(MsgEchoRedrawContent msg, Tid requestingThread) {
					if (_output_all_messages) { writeln("got MsgEchoRedrawContent\r"); }
					// this one is sent from the Gui to indicate 
					// that all requests were sent
					import gui;
					requestingThread.send(MsgRedrawContent(msg.gui_idx));
				},
				(MsgEchoFitContent msg, Tid requestingThread) {
					if (_output_all_messages) { writeln("got MsgEchoFitContent\r"); }
					// this one is sent from the Gui to indicate 
					// that all requests were sent
					import gui;
					requestingThread.send(MsgFitContent(msg.gui_idx));
				},
				(MsgGuiStarted msg, Tid guiTid) {
					if (_output_all_messages) { writeln("got MsgGuiStarted\r"); }
					_guiRunning = true;
					_guiTid = guiTid;
				},
				(MsgGuiQuit msg) {
					if (_output_all_messages) { writeln("got MsgGuiQuit\r"); }
					import std.stdio;
					_guiRunning = false;
				},
				(MsgIsGuiRunning msg, Tid requestingThread) {
					if (_output_all_messages) { writeln("got MsgIsGuiRunning\r"); }
					requestingThread.send(MsgGuiRunningStatus(_guiRunning));
				}
			); // receive
 		}  
		import std.stdio;
		writeln("sesson loop ended...\r");
	} catch (Exception t) {
			import std.stdio;
			writeln("Exception in session loop: ", t.msg);
			return false;
	}
		return true;

	}

private:
	bool _running;
	bool _output_all_messages = false;

	Item[string] _items;

	import std.concurrency;
	bool _guiRunning = false;
	Tid _guiTid;

	int _colorIdx_counter = 0;
}

void runSession()
{
	////////////////////////////////////////
	// create the main Session object 
	auto session = new Session;

	////////////////////////////////////////
	// run the session forever
	while (true) {
		if (!session.run()) {
			break;
		}
		import std.concurrency;

		////////////////////////////////////////
		// Wait here and only continue if 
		// MsgRun is send
		bool waiting = true;
		while (waiting) {
			receive(
				(MsgRun run, Tid requestingThread){
					waiting = false;
					requestingThread.send("session running");
					},
				(MsgStop stop, Tid requestingThread){
					requestingThread.send("session is already stopped");
				});
		}
	}
}
