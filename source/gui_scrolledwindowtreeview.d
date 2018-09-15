



class ScrolledWindowTreeView 
{
public: 
	//auto get() {
	//	return _treeview_scrollwin;
	//}
	// instead of the get() function we can do suptyping with alias this
	alias _treeview_scrollwin this;

	import std.concurrency;
	this(Tid sessionTid, Gui parentGui) {
		_sessionTid = sessionTid;
		_parentGui = parentGui; // a refrence to the parent Gui
		// define the layout (number and types of columns for the treeview)
		_treestore = new TreeStore([GType.STRING,GType.STRING]);
		_treeview = new TreeView(_treestore);

		import gtk.TreeViewColumn, gtk.CellRendererText;
		auto renderer = new CellRendererText;
		_treeview.appendColumn(new TreeViewColumn("Name", renderer, "text", 0));
		_treeview.appendColumn(new TreeViewColumn("Type", renderer, "text", 1)); 
		_treeview.getSelection().setMode(GtkSelectionMode.MULTIPLE);

		_treeview_scrollwin = new ScrolledWindow();
		_treeview_scrollwin.setPropagateNaturalHeight(true);
		_treeview_scrollwin.setPropagateNaturalWidth(true);
		_treeview_scrollwin.add(_treeview);


		import gtk.TreeIter, gtk.TreePath, gtk.TreeView;
		_treeview.addOnRowExpanded(
			delegate void(TreeIter iter, TreePath path, TreeView view) {
				string expanded_row = get_full_name_from_path(path.toString(), _itemnames);
				// remember which rows are expanded;
				_expanded[expanded_row] = true;
			}
		);
		_treeview.addOnRowCollapsed(
			delegate void(TreeIter iter, TreePath path, TreeView view) {
				string expanded_row = get_full_name_from_path(path.toString(), _itemnames);
				// remember which rows are collapsed;
				_expanded[expanded_row] = false;
			}
		);


		////////////////////////////////////////////////////////
		// define the popup menu for the list items
		import gtk.Menu, gtk.MenuItem;
		auto popup_menu = new Menu;
		popup_menu.append( // show selected recursive (if a folder is selected show all contents recursively)
			new MenuItem(
				delegate(MenuItem m) { // the action to perform if that menu entry is selected
					// look at all selected entries in the treeview ...
					auto iters = _treeview.getSelectedIters();
					import std.concurrency, std.array, std.algorithm, std.stdio;
					import session;
					foreach(iter; iters) {
						foreach(itemname; _itemnames.sort) {
							auto selected_name = get_full_name(iter);
							if (itemname.startsWith(selected_name)) {
								// request a Visualizer for that item
								_sessionTid.send(MsgRequestItemVisualizer(itemname, _parentGui.getGuiIdx()), thisTid);
							}
						}					
					}
					// ask the session to send us a "FitContent message"
					_sessionTid.send(MsgEchoFitContent(_parentGui.getGuiIdx()), thisTid); 
					// ask the session to send us a "RedrawContent message"
					_sessionTid.send(MsgEchoRedrawContent(_parentGui.getGuiIdx()), thisTid);
				},
				"show selected recusive", // menu entry label
				"show seleted items and all items in selected folders"// description
			)
		);		
		popup_menu.append( // show selected recursive (if a folder is selected show all contents recursively)
			new MenuItem(
				delegate(MenuItem m) { // the action to perform if that menu entry is selected
					// look at all selected entries in the treeview ...
					auto gui = new Gui(_parentGui.getApplication(), _sessionTid, _parentGui.getInOtherThread(), false, true); 
					auto iters = _treeview.getSelectedIters();
					import std.concurrency, std.array, std.algorithm, std.stdio;
					import session;
					foreach(iter; iters) {
						foreach(itemname; _itemnames.sort) {
							auto selected_name = get_full_name(iter);
							if (itemname.startsWith(selected_name)) {
								// request a Visualizer for that item
								_sessionTid.send(MsgRequestItemVisualizer(itemname, gui.getGuiIdx()), thisTid);
							}
						}					
					}
					// ask the session to send us a "FitContent message"
					_sessionTid.send(MsgEchoFitContent(gui.getGuiIdx()), thisTid); 
					// ask the session to send us a "RedrawContent message"
					_sessionTid.send(MsgEchoRedrawContent(gui.getGuiIdx()), thisTid);
				},
				"show in new window", // menu entry label
				"show seleted items and all items in selected folders in a new window"// description
			)
		);		
		popup_menu.append( // remove item
			new MenuItem(
				delegate(MenuItem m) { // the action to perform if that menu entry is selected
					// look at all selected entries in the treeview ...
					auto iters = _treeview.getSelectedIters();
					import std.concurrency, std.array, std.algorithm, std.stdio;
					import session;
					foreach(iter; iters) {
						foreach(itemname; _itemnames.sort) {
							auto selected_name = get_full_name(iter);
							if (itemname.startsWith(selected_name)) {
								// request a Visualizer for that item
								_sessionTid.send(MsgRemoveItem(itemname), thisTid);
							}
						}					
					}
				},
				"remove selected recusive", // menu entry label
				"remove seleted items and all items in selected folders"// description
			)
		);
		import gtk.Widget;
		_treeview.addOnButtonPress(
			delegate bool(GdkEventButton* e, Widget w) {
				w.onButtonPressEvent(e); 
				if (e.button == 3)	{
					popup_menu.popup(e.button, e.time);
					popup_menu.showAll(); 
				}
				//writeln("tree view button press event\r"); 
				return true;
			} //anonymous function
		);

	}


	string get_full_name(TreeIter iter) 
	{
		import std.stdio;
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
	string get_tree_path(TreeStore treestore, TreeIter iter) {
		return treestore.getPath(iter).toString();
	}


	TreeIter* add_folder(string name, ref TreeIter[string] folders) {
		import std.string;
		//writeln("add_folder(", name, ")\r");
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
	TreeIter add_item(string name, string typename, ref TreeIter[string] folders) {
		import std.algorithm, std.string;
		//writeln("add_item(", name, ")\r");
		if (!name.canFind('/')) { // special case of a name without a folder
			auto root_child = _treestore.append(null);
			folders[name~"/"] = root_child;
			_treestore.set(root_child, [0,1], [name, typename]);
			return root_child;
		}
		auto idx = name.lastIndexOf('/');
		// a/b/c
		assert(idx != (name.length-1)); // not allowed to end in '/'
		auto folder  = name[0..idx+1]; // /a/b/
		auto relname = name[idx+1..$]; // c
		//writeln("search " , folder, " in ", folders ,"\r");
		TreeIter *iter = (folder in folders);
		if (iter == null) {
			//writeln("adding folder: ", folder);
			iter = add_folder(folder, folders);
		}
		auto child = _treestore.append(*iter);
		folders[name~"/"] = child;
		_treestore.set(child, [0,1], [relname, typename]);
		return child;
	}
	import session;
	void updateTreeStoreFromSession(MsgItemList itemlist)
	{		
		_treestore.clear();
		TreeIter[string] _folders;

		import std.string, std.array, std.algorithm;
		_itemnames.length = 0;
		_typenames.length = 0;
		foreach(nametype; itemlist.nametype.split('|').array.sort) {
			_itemnames ~= nametype.split('$').array[0];
			_typenames ~= nametype.split('$').array[1];
		}

		TreeIter[string] folders;
		foreach(idx, itemname; _itemnames) {
			add_item(itemname, _typenames[idx], folders);
		}

		if (_itemnames is null) {
			return;
		}

		// expand all treeview rows that were expanded before
		string[] removed_expansions;
		foreach(expanded_name; _expanded.byKey().array().sort().array)
		{
			import gtk.TreePath;
			// test if this folder is still present
			bool present = false;
			foreach(item; _itemnames) {
				if (item.startsWith(expanded_name)) {
					present = true;
					break;
				} 
			}
			if (present) {
				string mypath = get_path_name_from_name(expanded_name, _itemnames);
				TreeIter iter;
				_treestore.getIterFromString(iter, mypath);
				TreePath path = _treestore.getPath(iter);
				string theirpath = _treestore.getStringFromIter(iter);
				if (_expanded[expanded_name]) {
					_treeview.expandRow(path, false);
				}
			} else {
				removed_expansions ~= expanded_name;
			}
		}
		foreach(rem_ex; removed_expansions) {
			_expanded.remove(rem_ex);
		}
	}

private:
	Tid _sessionTid;
	import gui;
	Gui _parentGui;

	import gtk.TreeStore, gtk.TreeView, gtk.TreeIter, gtk.ScrolledWindow;
	// widgets for treeview
	TreeStore      _treestore;
	TreeView       _treeview;

	string[] 		_itemnames;
	string[]        _typenames;

	// remember which treeview rows are expanded
	bool[string] _expanded; 

public: 
	// this has to be public to be used with alias this
	ScrolledWindow _treeview_scrollwin;
}

// path is something like 0:3:1
string get_full_name_from_path(string path, string[] itemnames)
{
	assert(itemnames.length > 0);
	assert(path.length > 0);
	import std.array, std.string, std.algorithm, std.conv;
	auto columns = path.split(':').length;
	int[] pathnumbers = std.algorithm.map!(a => a.to!int)(path.split(':')).array;
	int itemindex = 0;
	foreach (col; 0..columns) {
		// decreasing the pathnumbers until reaching 0
		while (pathnumbers[col] != 0 || itemnames[itemindex].split('/').length < columns) { 
			++itemindex;
			if (itemnames[itemindex].split('/')[0..col+1] != itemnames[itemindex-1].split('/')[0..col+1]) {
				--pathnumbers[col];
			}
		}
	}
	return itemnames[itemindex].split('/')[0..columns].join("/");
}

string get_path_name_from_name(string name, string[] itemnames)
{
	assert(itemnames.length > 0);
	assert(name.length > 0);
	import std.array, std.string, std.algorithm, std.conv;
	auto columns = name.split('/').length;
	int[] pathnumbers = new int[columns]; // will contain the result as integers
	int itemindex = 0; // index into the itemnames array
	foreach (col; 0..columns) {
		string[] target = name.split('/')[0..col+1];
		while(target.length > itemnames[itemindex].split('/').length) {
			// if the current item is too short, we go to the next in the list
			++itemindex;
		}
		while (target != itemnames[itemindex].split('/')[0..col+1]) {
			++itemindex;
			// is there a change to the previous item?
			if (itemnames[itemindex].split('/')[0..col+1] != 
				itemnames[itemindex-1].split('/')[0..col+1]) {
				++pathnumbers[col];
			}
		}
	}
	// convert the result into "x:y:z" form 
	string result = std.algorithm.map!(a => a.to!string)(pathnumbers).join(":");
	return result;
}

