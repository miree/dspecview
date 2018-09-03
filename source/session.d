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
}

////////////////////////////////////////
// All objects that are created by items
// in order to draw it have to impelement
// this interface. Visualizer objects 
// are shared between theads and have 
// therefore to be immutable
immutable interface Visualizer 
{
public:
	import cairo.Context, cairo.Surface;
	import view;
	void print(int context) immutable;
	void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz) immutable;
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

////////////////////////////////////////
// Add a test item to the
// list of items under the given name
struct MsgAddIntValue{
	string name;
	int value;
}

////////////////////////////////////////
// Add a 1d file histogram
struct MsgAddFileHist1{
	string filename;
}


////////////////////////////////////////
// Write a list of items to terminal
struct MsgRequestItemList{
}

////////////////////////////////////////
// call the refresh function on an item
struct MsgRequestItemVisualizer {
	string itemname;
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
			//receiveTimeout(dur!"usecs"(50_000), // 50 ms
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
				(MsgAddIntValue addItem) {
					import intValue;
					_items[addItem.name] = new IntValue(addItem.value);
				},
				(MsgAddFileHist1 filehist1, Tid requestingThread) {
					try {
						import hist1;
						_items[filehist1.filename] = new FileHist1(filehist1.filename);
						requestingThread.send("added filehist1: " ~ filehist1.filename);
					} catch (Exception e) {
						requestingThread.send(e.msg);
					}
				},
				(MsgRequestItemList msg, Tid requestingThread) {
					import textui;
					if (_items.length == 0) {
						requestingThread.send(MsgItemList());
					} else {
						string itemlist; // will contains items separated by spaces (' ')
						foreach(key, value; _items) {
							itemlist ~= key ~ ' ';
						}
						itemlist = itemlist[0..$-1]; // remove last ' '

						// send the resoponse
						requestingThread.send(MsgItemList(itemlist));
					}
				},
				(MsgRequestItemVisualizer msg, Tid requestingThread) {
					auto item = msg.itemname in _items;
					if (item is null) {
						requestingThread.send("unknown item: " ~ msg.itemname);
					} else {
						requestingThread.send(item.createVisualizer());
					}
				}
			); // receive
		}
	}

private:
	bool _running;

	Item[string] _items;
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
