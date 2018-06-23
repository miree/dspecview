import std.stdio;
import std.string;
import std.algorithm;
import std.array;

import gio.Application : GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Button;
import gtk.ScrolledWindow;
import gtk.Box;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.TreeStore;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.CellRendererText;
import gdk.Event;
import gtk.Widget;
import gtk.Menu;
import gtk.MenuItem;
import gdk.Threads;

import glib.Thread;

import session;

import PlotArea;

void say_hello(Button button)
{
	writeln("button_clicked ", button.getLabel());
}

bool on_button_press_event(GdkEventButton* e, Widget w)
{
	// do whatever we want
	writeln("button press event");

	return w.onButtonPressEvent(e); // worward the event to widget to get the default action
}

extern(C) nothrow static int threadIdleProcess(void* data) {
	//Don't let D exceptions get thrown from function
	try{
		import std.concurrency;
		import std.variant : Variant;
		import std.datetime;
		receiveTimeout(dur!"msecs"(1),(int i) { 
					Gui gui = cast(Gui)data;
					gui.updateSession();
				}
			);
		//writeln("idle called");
	} catch (Throwable t) {
		return 0;
	}
	return 1;
}

int run(immutable string[] args, shared Session session)
{
	auto application = new Application("de.egelsbach.dspecview", GApplicationFlags.FLAGS_NONE);
	application.addOnActivate(delegate void(GioApplication app) { 
			auto gui = new Gui(application, session); 
			gdk.Threads.threadsAddIdle(&threadIdleProcess, cast(void*)gui);	
		});
	return application.run(cast(string[])args);
}

//struct Helper
//{
//	import gtk.TreePath;
//	TreePath[] expanded_paths = new TreePath[0];
//}
//extern(C) void expandedMapper(GtkTreeView* treeView, GtkTreePath* path, void* userData)
//{
//	auto helper = cast(Helper*)userData;
//	import gtk.TreePath;
//	auto p = new TreePath(path);
//	helper.expanded_paths ~= p;
//	writeln("expanded row path: ", p.toString(), "\r");
//}

class Gui : ApplicationWindow
{

	TreeIter* add_folder(string name, ref TreeIter[string] folders) {
		writeln("add_folder(", name, ")\r");
		assert(name.lastIndexOf('/') == (name.length-1));
		// a/b/c/
		auto idx = lastIndexOf(name[0..$-1],'/');
		auto base = name[0..idx+1]; // a/b/
		auto head = name[idx+1..$]; // c/
		//writeln(base,"   ", head);
		if (base == "") folders[base] = null; // insert the toplevel dir
		TreeIter *iter = (base in folders);
		if (iter == null) iter = add_folder(base, folders);
		iter = &(folders[name] = _treestore.append(*iter));
		_treestore.set(*iter, [0,1], [head[0..$-1], ""]);
		return iter;
	}
	TreeIter add_item(string name, ref TreeIter[string] folders) {
		writeln("add_item(", name, ")\r");
		auto idx = name.lastIndexOf('/');
		// a/b/c
		assert(idx != (name.length-1)); // not allowed to end in '/'
		auto folder  = name[0..idx+1]; // /a/b/
		auto relname = name[idx+1..$]; // c
		writeln("search " , folder, " in ", folders ,"\r");
		TreeIter *iter = (folder in folders);
		if (iter == null) {
			writeln("adding folder: ", folder);
			iter = add_folder(folder, folders);
		}
		auto child = _treestore.append(*iter);
		folders[name~"/"] = child;
		_treestore.set(child, [0,1], [relname, "item"]);
		return child;
	}

	void updateSession()
	{
		_treestore.clear();
		TreeIter[string] _folders;
		synchronized {
			_items = _session.getItems().byKey().array().sort().array;
		}
		foreach(item_fullname; _items) {
			add_item(item_fullname, _folders);
			foreach(key;_folders.byKey().array().sort())	{
				writeln(key , "\r");
			}
		}

		foreach(expanded_name; _expanded.byKey().array().sort().array)
		{
			writeln("expand ", expanded_name, "\r");
		}
		foreach(expanded_name; _expanded.byKey().array().sort().array)
		{
			writeln("expand ", expanded_name, "\r");
			string mypath = get_path_name_from_name(expanded_name);
			TreeIter iter;
			_treestore.getIterFromString(iter, mypath);
			TreePath path = _treestore.getPath(iter);
			string theirpath = _treestore.getStringFromIter(iter);
			//writeln("mypath = ", mypath, ",    theirpath = ", theirpath, "\r");
			if (_expanded[expanded_name]) {
				_treeview.expandRow(path, false);
			}
		}
	}

	string get_path_name_from_name(string name)
	{
		writeln("get_path_name_from_name(", name, ")\r");
		foreach(item; _items)
		{
			writeln("    ", item, "\r");
		}
		auto columns = name.split("/").length;
		writeln("number of columns: ", columns, "\r");
		int[] pathnumbers = new int[columns];
		int col = 0;
		int itemindex = 0;
		string test = "/" ~ _items[itemindex].split("/")[col];
		for (;;)
		{
			writeln("col = ", col , ",   test = ", test, ",  item = ", _items[itemindex],  "    pathnumbers = ", pathnumbers, "\r");
			if (name.startsWith(test[1..$])) {
				++col;
				if (col == columns) {
					break;
				}
				test ~= "/" ~ _items[itemindex].split("/")[col];
			} else {
				while (_items[itemindex].startsWith(test[1..$])) {
					++itemindex;
				}
				++pathnumbers[col];
				test = "";
				foreach(part; _items[itemindex].split("/")[0..col+1])	{
					test ~= "/" ~ part;
				}
			}
		}
		import std.algorithm, std.conv;
		string result = std.algorithm.map!(a => a.to!string)(pathnumbers).join(":");
		writeln("result  = ", result, "\r");
		return result;
	}
	string get_full_name_from_path(string path)	
	{
		writeln("get_full_name_from_path(", path, ")\r");
		import std.algorithm, std.conv;
		auto pathnumbers = std.algorithm.map!(a => to!int(a))(split(path,":"));
		int col = 0;
		int itemindex = 0;
		int pathvalue = 0;
		// increase itemindex until pathvalue matches pathnumbers[col]
		string result = "/" ~ _items[itemindex].split("/")[col];
		//writeln("get_full_name_from_path(", path,")\r");
		foreach(item; _items)
		{
			writeln("item ", item, "\r");
		}
		for(;;)
		{
			writeln("col = ", col, "     itemindex = ", itemindex, "     pathvalue = ", pathvalue, "    result = ", result,  "\r");
			if (pathvalue == pathnumbers[col]) {
				writeln("pathvalue == pathnumbers[", col, "]\r");
				++col;
				if (pathnumbers.length > col) { // show must go on
					writeln(pathnumbers.length , ">", col , "\r");
					if (col >= _items[itemindex].split("/").length) {
						++itemindex;
						--col;
						continue;
					}
					result ~= "/" ~ _items[itemindex].split("/")[col];
					pathvalue = 0; // start counting from 0 in the new column
					continue;
				} else {
					writeln("done: ",result[1..$],  "\r");
					return result[1..$]; // we are done
				}
			} else { 
				writeln("goto next item\r");
				for(;;) {
					++itemindex; // go to next item
					writeln("itemindex = ", itemindex, "\r");
					if (!startsWith(_items[itemindex], result[1..$])) {
						++pathvalue;
						result.length = 0;
						foreach(part; _items[itemindex].split("/")[0..col+1]) {
							result ~= "/" ~ part;
						}
						break;
					}
				}
			}
		}
	}

	string get_full_name(TreeIter iter) 
	{
		if (iter is null) {
			writeln("get_full_name() ... iter is null\r");
			return "";
		}
		auto parent = iter.getParent();
		if (parent is null) {
			return iter.getValueString(0);
		} else {
			return get_full_name(parent) ~ "/" ~ iter.getValueString(0);
		}
	}
	string get_tree_path(TreeIter iter) {
		return _treestore.getPath(iter).toString();
	}

	this(Application application, shared Session session)
	{
		_session = session;
		import std.stdio;
		
		super(application);

		setTitle("gtkD Spectrum Viewer");
		setDefaultSize( 300, 500 );

		auto box = new Box(GtkOrientation.VERTICAL,0);

		_treestore = new TreeStore([GType.STRING,GType.STRING]);
		_treeview = new TreeView(_treestore);

		auto b1 = new Button("Hallo"); 
		     b1.addOnClicked(button => say_hello(button));

		auto b2 = new Button("clear");  
			 b2.addOnClicked(button => _treestore.clear());

		auto b3 = new Button("refresh"); 
		     b3.addOnClicked(botton => updateSession());

		// add all column data
		auto renderer = new CellRendererText;
		//  compact way of addin a column
		_treeview.appendColumn(new TreeViewColumn("Name", renderer, "text", 0));
		_treeview.appendColumn(new TreeViewColumn("Type", renderer, "text", 1)); 

		_treeview.getSelection().setMode(GtkSelectionMode.MULTIPLE);


		// create the popup menu content
		auto popup_menu = new Menu;
		//popup_menu.append(new MenuItem((MenuItem)=>writeln("selected: ", treeview.getSelectedIter().getValueString(0)), "show",    "in new window"));
		//popup_menu.append(new MenuItem((MenuItem)=>writeln("delete ", treeview.getSelectedIter().getValueString(0), " ", _treestore.remove(treeview.getSelectedIter())),  "delete",  "delete the item"));
		popup_menu.append( new MenuItem(
								delegate(MenuItem m) { // the action to perform if that menu entry is selected
									write("show: ");
									auto iter = _treeview.getSelectedIter();
									if (iter is null) {
										writeln("nothing selected");
									} else {
										writeln(get_full_name(iter));
									}
								},
								"show", // menu entry label
								"show in new window"// description
							));
		popup_menu.append( new MenuItem(
								delegate(MenuItem m) { // the action to perform if that menu entry is selected
									writeln("show all: ");
									auto iters = _treeview.getSelectedIters();
									foreach(iter; iters)
									{
										writeln(get_full_name(iter));										
									}
								},
								"show all", // menu entry label
								"show all seleted items"// description
							));
		popup_menu.append( new MenuItem(
								delegate(MenuItem m) { // the action to perform if that menu entry is selected
									//for (;;)
									//{
										writeln("delete ");
										auto iters = _treeview.getSelectedIters();
										foreach(iter; iters) 
										{
											_session.removeItem(get_full_name(iter));
										}
										updateSession();
										//if (iter is null) {
										//	writeln("nothing selected");
										//	//break;
										//} else {
										//	//writeln(iter.getValueString(0));
										//	//writeln(get_full_name(iter));
										//	_session.removeItem(get_full_name(iter));
										//	//_treestore.remove(iter);
										//}
									//}
								}, 
								"delete",  // menu entry label
								"delete selected item" // description
							));

		_treeview.addOnButtonPress(
			//(GdkEventButton* e, Widget w)=>on_button_press_event(e,w) // explicit function call
			delegate bool(GdkEventButton* e, Widget w) {
				w.onButtonPressEvent(e); 
				if (e.button == 3)	{
					popup_menu.popup(e.button, e.time);
					popup_menu.showAll(); 
				}
				writeln("tree view button press event\r"); 
				return true;
			} //anonymous function
			//(GdkEventButton* e, Widget w)=>w.onButtonPressEvent(e) // shortcut lambda syntax only works for function with a single return statement
			);

		_treeview.addOnRowExpanded(
				delegate void(TreeIter iter, TreePath path, TreeView view) {
					writeln("addOnRowExpanded() ", path.toString(), "\r");
					string expanded_row = get_full_name_from_path(path.toString());
					//writeln(expanded_row, "\r");
					_expanded[expanded_row] = true;
				}
			);
		_treeview.addOnRowCollapsed(
				delegate void(TreeIter iter, TreePath path, TreeView view) {
					writeln("addOnRowCollapsed() ", path.toString(), "\r");
					string expanded_row = get_full_name_from_path(path.toString());
					//writeln(expanded_row, "\r");
					_expanded[expanded_row] = false;
				}
			);



		updateSession();

		// create the tree view content
		//auto top = _treestore.createIter; // toplevel of the tree
		//_treestore.set(top, [0,1], ["WeltA","WeltB"]);
		//top = _treestore.append(null); // append(null) creates a new row that is NO child of the previous row
		//_treestore.set(top, [0,1], ["X","Y"]);
		//top = _treestore.append(null); // another new row that is no child
		////auto path = new TreePath(true);
		//_treestore.setValue(top, 0, "Hallo"); _treestore.setValue(top, 1, "Welt");
		//auto child = _treestore.append(top); // another row that is a child of the row to which top points
		//_treestore.set(child, [0,1], ["Hello10","World1"]);
		//child = _treestore.append(top); // another row that is a child of the row to which top points
		//_treestore.set(child, [0,1], ["Hello2","World2"]);
		//child = _treestore.append(top); // another row that is a child of the row to which top points
		//_treestore.set(child, [0,1], ["Hello3","World3"]);
		//child = _treestore.append(top); // another row that is a child of the row to which top points
		//_treestore.set(child, [0,1], ["Hello4","World4"]);


		
		// add buttons 
		box.add(b1);
		box.add(b2);
		box.add(b3);

		// add the treeview ...
		//    ... with scrolling
		auto scrollwin = new ScrolledWindow();
		scrollwin.setPropagateNaturalHeight(true);
		scrollwin.add(_treeview);
		box.add(scrollwin); 
		//    ... without scrolling
		//box.add(treeview);

		auto plot_area = new PlotArea;
		box.add(plot_area);
		//plot_area.setSizeRequest(200,200);
		box.setChildPacking(plot_area,true,true,0,GtkPackType.START);

		plot_area.show();

		b1.show();
		b2.show();
		_treeview.show();

		add(box);
		showAll();
	}

	TreeStore _treestore;
	TreeView  _treeview;
	string[] _items; // the session items that are currently in the _treestore
	bool[string] _expanded; // safe which treeview rows are expanded
	//TreeIter[string] _folders;
	shared Session _session;

}
