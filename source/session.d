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
	import cairo.Context, cairo.Surface;
	import view;
	string getItemName() immutable;
	ulong getDim() immutable;
	void print(int context) immutable;
	void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz) immutable;
	bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable;
	bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable;
	bool getZminZmaxInLeftRightBottomTop(out double mi, out double ma, 
	                                     double left, double right, double bottom, double top, 
	                                     bool logz, bool logy, bool logx) immutable;

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

//////////////////////////////////////////
//// Add a test item to the
//// list of items under the given name
//struct MsgAddIntValue{
//	string name;
//	int value;
//}

////////////////////////////////////////
// Add a 1d file histogram
struct MsgAddFileHist1{
	string filename;
}

struct MsgRemoveItem{
	string itemname;
}


////////////////////////////////////////
// Write a list of items to terminal
struct MsgRequestItemList{
}
// response to the above request
struct MsgItemList { 
	string nametype; 
};

////////////////////////////////////////
// call the refresh function on an item
struct MsgRequestItemVisualizer {
	string itemname;
	ulong gui_idx;
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
	void run()
	{
		_running = true;

		////////////////////////////////////////
		// The main event loop. 
		// Messages send to this thread control 
		// the entire session.
		import std.concurrency;
		import std.variant : Variant;
		import std.datetime;

		while (_running) {
			import std.stdio;
			//writeln("session: tick\r");
			//receiveTimeout(dur!"usecs"(500_000), // 500 ms
			receive(
				(MsgSayHi msg, Tid requestingThread) { 
					requestingThread.send("message to session was: " ~ msg.text);
				},
				(MsgStop stop, Tid requestingThread) {
					_running = false;
					requestingThread.send("session stopped");
				},
				(MsgRun run, Tid requestingThread) {
					requestingThread.send("session is already running");
				},
				(MsgRemoveItem msg, Tid requestingThread) {
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
				(MsgAddFileHist1 filehist1, Tid requestingThread) {
					try {
						import hist1;
						_items[filehist1.filename] = new FileHist1(filehist1.filename);
						//requestingThread.send("added filehist1: " ~ filehist1.filename);
						if (_guiRunning) {
							import gui;
							_guiTid.send(MsgRefreshItemList());
						}
					} catch (Exception e) {
						//requestingThread.send(e.msg);
					}
				},
				(MsgRequestItemList msg, Tid requestingThread) {
					import textui;
					if (_items.length == 0) {
						requestingThread.send(MsgItemList());
					} else {
						string itemlist; // will contains items separated by spaces (' ')
						foreach(itemname, item; _items) {
							itemlist ~= itemname ~ '$' ~ item.getTypeString() ~ '|';
						}
						itemlist = itemlist[0..$-1]; // remove last ' '

						// send the resoponse
						requestingThread.send(MsgItemList(itemlist));
					}
				},
				(MsgRequestItemVisualizer msg, Tid requestingThread) {
					import std.stdio;
					auto item = msg.itemname in _items;
					if (item is null) {
						//writeln("session: unknown item: ", msg.itemname, "\r");
						requestingThread.send("unknown item: " ~ msg.itemname);
					} else {
						import gui;
						//writeln("session: sending visualizer for: ", msg.itemname, "\r");
						requestingThread.send(MsgVisualizeItem(msg.itemname, msg.gui_idx), item.createVisualizer());
						//writeln("session: sending visualizer done \r");
					}
				},
				(MsgEchoRedrawContent msg, Tid requestingThread) {
					// this one is sent from the Gui to indicate 
					// that all requests were sent
					import gui;
					requestingThread.send(MsgRedrawContent(msg.gui_idx));
				},
				(MsgEchoFitContent msg, Tid requestingThread) {
					// this one is sent from the Gui to indicate 
					// that all requests were sent
					import gui;
					requestingThread.send(MsgFitContent(msg.gui_idx));
				},
				(MsgGuiStarted msg, Tid guiTid) {
					_guiRunning = true;
					_guiTid = guiTid;
				},
				(MsgGuiQuit msg) {
					import std.stdio;
					_guiRunning = false;
				},
				(MsgIsGuiRunning msg, Tid requestingThread) {
					requestingThread.send(MsgGuiRunningStatus(_guiRunning));
				}
			); // receive
		}
	}

private:
	bool _running;

	Item[string] _items;

	import std.concurrency;
	bool _guiRunning = false;
	Tid _guiTid;
}

void runSession()
{
	////////////////////////////////////////
	// create the main Session object 
	auto session = new Session;

	////////////////////////////////////////
	// run the session forever
	while (true) {
		session.run();
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
