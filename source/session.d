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
	int getColorIdx() immutable;
	ulong getDim() immutable;
	void print(int context) immutable;
	bool needsColorKey() immutable;
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
struct MsgAddFileHist2{
	string filename;
}
struct MsgAddGuiItem{
	string guiname;
	ulong gui_idx;
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
				(MsgAddFileHist1 filehist1, Tid requestingThread) {
					if (_output_all_messages) { writeln("got MsgAddFileHist1\r"); }
					try {
						import hist1;
						_items[filehist1.filename] = new FileHist1(filehist1.filename, _colorIdx_counter++);
						//requestingThread.send("added filehist1: " ~ filehist1.filename);
						if (_guiRunning) {
							import gui;
							_guiTid.send(MsgRefreshItemList());
						}
					} catch (Exception e) {
						//requestingThread.send(e.msg);
					}
				},
				(MsgAddFileHist2 filehist2, Tid requestingThread) {
					if (_output_all_messages) { writeln("got MsgAddFileHist2\r"); }
					try {
						import hist2;
						_items[filehist2.filename] = new FileHist2(filehist2.filename, _colorIdx_counter++);
						//requestingThread.send("added filehist1: " ~ filehist1.filename);
						if (_guiRunning) {
							import gui;
							_guiTid.send(MsgRefreshItemList());
						}
					} catch (Exception e) {
						//requestingThread.send(e.msg);
					}
				},
				(MsgAddGuiItem guiitem, Tid requestingThread) {
					if (_output_all_messages) { writeln("got MsgAddGuiItem\r"); }
					import gui;
					import std.conv;
					_items[guiitem.guiname] = new GuiItem(guiitem.guiname, guiitem.gui_idx);
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
