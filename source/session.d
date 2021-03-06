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

	////////////////////////////////////////
	// Notification that an item changed 
	// or was newly created. 
	// give name and reference to it
	void notifyItemChanged(string itemname, Item item);

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
	string gui_name;
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
	bool mouseDistance(ViewBox box, out double dx, out double dy, out double dr, double x, double y, bool logx, bool logy, VisualizerContext context) immutable;
	void mouseButtonDown(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable;
	void mouseDrag(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable;
	void mouseButtonUp(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable;
	void deleteKeyPressed(Tid sessionTid, ItemMouseAction mouse_action, VisualizerContext context) immutable;
	VisualizerContext createContext() immutable;
	bool isInteractive() immutable; // if this is true, a visualizer cannot be updated via refresh. 
	                                // The implementation has to make sure that updates are send to other gui windows
	                                // via the message gui.MsgAllButMyselfUpdateVisualizer
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

	override bool mouseDistance(ViewBox box, out double dx, out double dy, out double dr, double x, double y, bool logx, bool logy, VisualizerContext context) immutable
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
	override void deleteKeyPressed(Tid sessionTid, ItemMouseAction mouse_action, VisualizerContext context) immutable
	{
	}
	override VisualizerContext createContext() immutable
	{
		return new VisualizerContext();
	}
	override bool isInteractive() immutable
	{
		return false;
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

struct MsgInsertItem {
	string itemname;
	immutable(Item) item;
}


////////////////////////////////////////
// Write a list of items to terminal
struct MsgRequestItemList{
}
// response to the above request
struct MsgItemList { 
	string nametype; 
}
struct MsgRequestRefreshItemList {
}
struct MsgRequestItemUpdate {
}
struct MsgUpdateItem { 
	string nametype; 
}

////////////////////////////////////////
// Histogram operations
struct MsgFillHist1 {
	string itemname;
	double pos;
	double amount;
}

////////////////////////////////////////
// call the refresh function on an item
struct MsgRequestItemVisualizer {
	string itemname;
	string gui_name;
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
	string gui_name;
}
struct MsgEchoFitContent {
	string gui_name;
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


///////////////////////////////
// Messages for data ananlysis
// stepping
struct MsgStartAnalysis {
	string itemname;
	long   count = -1; // -1 means infinite number of steps
}
struct MsgAnalysisStep {
	import analysis;
	immutable(Analysis) anl;
	bool stop = false;
}

struct MsgStartSoundScope {
	string itemname;
	long   count = -1; // -1 means infinite number of steps
}
struct MsgSoundScopeStep {
	import soundscope;
	immutable(SoundScope) anl;
	bool stop = false;
}

///////////////////////////////
// Messages for notification 
// mechanism
struct MsgNotifyMeOnItemChange {
	string me;
	string name_of_changed_item;
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
									//writeln("already_there\r");
									_guiTid.send(MsgUpdateItem(itemname ~ "$" ~ _items[itemname].getTypeString() ~ "$" ~ _items[itemname].getColorIdx().to!string));
								} else {
									_guiTid.send(MsgRefreshItemList());
								}
							}
							notify_all(itemname);
						} catch (Exception e) {
							//requestingThread.send(e.msg);
						}
					},
					(MsgInsertItem msg) {
						if (_output_all_messages) { writeln("got MsgInsertItem\r"); }
						try {
							string itemname = msg.itemname;

							_items[itemname] = cast(Item)msg.item;
							if (_guiRunning) {
								import gui;
								_guiTid.send(MsgRefreshItemList());
							}
							notify_all(itemname);
						} catch (Exception e) {
							//requestingThread.send(e.msg);
						}
					},
					(MsgRequestRefreshItemList msg) {
						if (_guiRunning) {
							import gui;
							_guiTid.send(MsgRefreshItemList());
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
									//writeln("visualizer ", msg.itemname , "sent to ", msg.gui_name, "\r");
									requestingThread.send(MsgVisualizeItem(msg.itemname, msg.gui_name), visualizer);
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
						requestingThread.send(MsgRedrawContent(msg.gui_name));
					},
					(MsgEchoFitContent msg, Tid requestingThread) {
						if (_output_all_messages) { writeln("got MsgEchoFitContent\r"); }
						// this one is sent from the Gui to indicate 
						// that all requests were sent
						import gui;
						requestingThread.send(MsgFitContent(msg.gui_name));
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
					},
					(MsgFillHist1 msg) {
						if (_output_all_messages) { writeln("got MsgFillHist1\r"); }
						import hist1;
						auto item = msg.itemname in _items;
						if (item !is null) {
							//if (typeid(*item) is typeid(Hist1)) {
							auto hist = cast(Hist1Interface)(*item);
							if (hist !is null) {	
								//writeln("filling\r");
								hist.fill(msg.pos, msg.amount);
							} else {
								writeln("Item ", msg.itemname, " does not implement Hist1Interface \r");
							}
						} else {
							writeln("not filling\r");
						}
					},
					(MsgStartAnalysis msg) {
						if (_output_all_messages) { writeln("got MsgStartAnalysis\r"); }
						auto item = msg.itemname in _items;
						if (item !is null) {
							import analysis;
							auto anl_item = cast(AnalysisInterface)(*item);
							if (anl_item !is null) {
								//writeln("start analysis with ", msg.count, " steps\r");
								if (msg.count != 0) {
									anl_item.start(msg.count);
								} else {
									anl_item.stop();
								}
							}
						}
					},
					(MsgAnalysisStep msg) {
						if (_output_all_messages) { writeln("got MsgAnalysisStep\r"); }
						if (msg.anl !is null) {
							//writeln("    not null\r");
							import analysis;
							auto anl = cast(Analysis)msg.anl;
							anl.step();
						}
					},
					(MsgStartSoundScope msg) {
						if (_output_all_messages) { writeln("got MsgStartSoundScope\r"); }
						auto item = msg.itemname in _items;
						if (item !is null) {
							import soundscope;
							auto anl_item = cast(SoundScopeInterface)(*item);
							if (anl_item !is null) {
								//writeln("start SoundScope with ", msg.count, " steps\r");
								if (msg.count != 0) {
									anl_item.start(msg.count);
								} else {
									anl_item.stop();
								}
							}
						}
					},
					(MsgSoundScopeStep msg) {
						if (_output_all_messages) { writeln("got MsgSoundScopeStep\r"); }
						if (msg.anl !is null) {
							//writeln("    not null\r");
							import soundscope;
							auto anl = cast(SoundScope)msg.anl;
							anl.step();
						}
					},
					(MsgNotifyMeOnItemChange msg) {
						if (_output_all_messages) { writeln("got MsgNotifyMeOnItemChange\r"); }
						if (msg.name_of_changed_item !is null && msg.me !is null) {
							_notification_matrix[msg.name_of_changed_item] ~= msg.me;
						}
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

	void notify_all(string itemname_of_changed_item) {
		// see if the item is actually a thing
		auto changed_item_ptr = itemname_of_changed_item in _items;
		if (changed_item_ptr !is null) {
			// notify all other items as specified by the _notification_matrix
			auto list_of_itemnames_to_notify = itemname_of_changed_item in _notification_matrix;
			if (list_of_itemnames_to_notify !is null) {
				foreach(itemname_to_notify; *list_of_itemnames_to_notify) {
					auto notified_item_ptr = itemname_to_notify in _items;
					if (notified_item_ptr !is null) {
						(*notified_item_ptr).notifyItemChanged(itemname_of_changed_item, *changed_item_ptr);
					}
				}
			}
		}
	}

private:
	bool _running;
	bool _output_all_messages = false;

	Item[string] _items;
	string[][string] _notification_matrix; // 

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
