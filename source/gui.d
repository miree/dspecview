import std.stdio;
import std.string;
import std.algorithm;
import std.array;

import gio.Application : GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Button;
import gtk.ToggleButton;
import gtk.RadioButton;
import gtk.SpinButton;
import gtk.CheckButton;
import gtk.Label;
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
import plotarea;
import item;
import drawable;
import plotwindow;


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
		// get messages from parent thread
		receiveTimeout(dur!"usecs"(10),(int i) { 
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

int run(immutable string[] args, shared Session session, bool in_other_thread = false)
{
	auto application = new Application("de.egelsbach.dspecview", GApplicationFlags.FLAGS_NONE);
	application.addOnActivate(delegate void(GioApplication app) { 
			auto gui = new Gui(application, session, in_other_thread); 
			gdk.Threads.threadsAddIdle(&threadIdleProcess, cast(void*)gui);	
		});
	return application.run(cast(string[])args);
}

class Gui : ApplicationWindow
{

	void say_hello(Button button)
	{
		writeln("button_clicked ", button.getLabel());

		auto child_window = new PlotWindow(_application, _session, _in_other_thread);
		child_window.show();
	}


	TreeIter* add_folder(string name, ref TreeIter[string] folders) {
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
	TreeIter add_item(string name, ref TreeIter[string] folders) {
		//writeln("add_item(", name, ")\r");
		if (!name.canFind('/')) { // special case of a name without a folder
			auto root_child = _treestore.append(null);
			folders[name~"/"] = root_child;
			_treestore.set(root_child, [0,1], [name, "item"]);
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
		}

		foreach(expanded_name; _expanded.byKey().array().sort().array)
		{
			//writeln("expand ", expanded_name, "\r");
			string mypath = get_path_name_from_name(expanded_name, _items);
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

	// path is something like 0:3:1
	string get_full_name_from_path(string path, string[] items)
	{
		assert(items.length > 0);
		assert(path.length > 0);
		import std.array, std.string, std.algorithm, std.conv;
		auto columns = path.split(':').length;
		int[] pathnumbers = std.algorithm.map!(a => a.to!int)(path.split(':')).array;
		int itemindex = 0;
		foreach (col; 0..columns) {
			while (pathnumbers[col] != 0 || items[itemindex].split('/').length < columns) { // decreasing the pathnumbers until reaching 0
				++itemindex;
				if (items[itemindex].split('/')[0..col+1] != items[itemindex-1].split('/')[0..col+1]) {
					--pathnumbers[col];
				}
			}
		}
		return items[itemindex].split('/')[0..columns].join("/");
	}

	string get_path_name_from_name(string name, string[] items)
	{
		assert(items.length > 0);
		assert(name.length > 0);
		import std.array, std.string, std.algorithm, std.conv;
		auto columns = name.split('/').length;
		int[] pathnumbers = new int[columns]; // will contain the result as integers
		int itemindex = 0; // index into the items array
		foreach (col; 0..columns) {
			string[] target = name.split('/')[0..col+1];
			while(target.length > items[itemindex].split('/').length) {
				// if the current item is too short, we go to the next in the list
				++itemindex;
			}
			while (target != items[itemindex].split('/')[0..col+1]) {
				++itemindex;
				// is there a change to the previous item?
				if (items[itemindex].split('/')[0..col+1] != items[itemindex-1].split('/')[0..col+1]) {
					++pathnumbers[col];
				}
			}
		}
		// convert the result into "x:y:z" form 
		string result = std.algorithm.map!(a => a.to!string)(pathnumbers).join(":");
		return result;
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

	this(Application application, shared Session session, bool in_other_thread)
	{
		_session = session;
		_in_other_thread = in_other_thread;
		import std.stdio;
		
		super(application);
		_application = application;

		setTitle("gtkD Spectrum Viewer");
		setDefaultSize( 300, 500 );

		_box = new Box(GtkOrientation.VERTICAL,0);

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
		//popup_menu.append( new MenuItem(
		//						delegate(MenuItem m) { // the action to perform if that menu entry is selected
		//							write("show: ");
		//							auto iter = _treeview.getSelectedIter();
		//							if (iter is null) {
		//								writeln("nothing selected");
		//							} else {
		//								writeln(get_full_name(iter));
		//							}
		//						},
		//						"show", // menu entry label
		//						"show in new window"// description
		//					));
		popup_menu.append( new MenuItem(
								delegate(MenuItem m) { // the action to perform if that menu entry is selected
									//write("refreshing ");
									auto iters = _treeview.getSelectedIters();
									foreach(iter; iters)
									{
										string itemname = get_full_name(iter);
										import item;
										synchronized {
											shared Item selected_item = _session.getItem(itemname);
											if (selected_item is null) {
												writeln("item is null");
											} else {
												selected_item.refresh();
											}
										}
										//writeln(itemname, "\r");
									}
									_box.queueDraw();
								},
								"refresh", // menu entry label
								"refresh data content"// description
							));
		popup_menu.append( new MenuItem(
								delegate(MenuItem m) { // the action to perform if that menu entry is selected
									writeln("show all: ");
									auto iters = _treeview.getSelectedIters();
									foreach(iter; iters)
									{
										string itemname = get_full_name(iter);
										bool was_empty = _plot_area.isEmpty;
										_plot_area.add_drawable(itemname);
										if (was_empty) {
											_plot_area.setFit();
										}
									}
									_box.queueDraw();
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
									_box.queueDraw();
								}, 
								"delete",  // menu entry label
								"delete selected item" // description
							));

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

		_treeview.addOnRowExpanded(
				delegate void(TreeIter iter, TreePath path, TreeView view) {
					//writeln("addOnRowExpanded() ", path.toString(), "\r");
					string expanded_row = get_full_name_from_path(path.toString(), _items);
					//writeln(expanded_row, "\r");
					_expanded[expanded_row] = true;
				}
			);
		_treeview.addOnRowCollapsed(
				delegate void(TreeIter iter, TreePath path, TreeView view) {
					//writeln("addOnRowCollapsed() ", path.toString(), "\r");
					string expanded_row = get_full_name_from_path(path.toString(), _items);
					//writeln(expanded_row, "\r");
					_expanded[expanded_row] = false;
				}
			);



		updateSession();

		// add buttons 
		_box.add(b1);
		_box.add(b2);
		_box.add(b3);

		// add the treeview ...
		//    ... with scrolling
		auto scrollwin = new ScrolledWindow();
		scrollwin.setPropagateNaturalHeight(true);
		scrollwin.add(_treeview);
		_box.add(scrollwin); 
		//    ... without scrolling
		//_box.add(treeview);

		_plot_area = new PlotArea(_session, in_other_thread);
		_box.add(_plot_area);
		//plot_area.setSizeRequest(200,200);
		_box.setChildPacking(_plot_area,true,true,0,GtkPackType.START);
		_plot_area.show();

		b1.show();
		b2.show();
		_treeview.show();

		_radio_overlay = new RadioButton("overlay");
		_radio_overlay.addOnToggled(
							delegate void(ToggleButton button) {
								//writeln("overlay button toggled ", button.getActive(), "\r");
								if (button.getActive()) {
									_plot_area.setOverlay();
								} else {
									_plot_area.setGrid(cast(int)_spin_columns.getValue());
								}
								_box.queueDraw();
							} );

		_radio_grid = new RadioButton("grid");
		_radio_grid.joinGroup(_radio_overlay);
		auto columns_label = new Label("columns   ");
		_spin_columns = new SpinButton(1,50,1);
		_spin_columns.addOnValueChanged(
							delegate void(SpinButton button) {
								//writeln("spin button changed ", button.getValue(), "\r");
								if (_radio_overlay.getActive()) {
									_plot_area.setOverlay();
								} else {
									_plot_area.setGrid(cast(int)_spin_columns.getValue());
								}
								_box.queueDraw();
							} );
		_radio_rowmajor = new RadioButton("1 2\n34");
		_radio_rowmajor.addOnToggled(
							delegate void(ToggleButton button) {
								//writeln("overlay button toggled ", button.getActive(), "\r");
								if (button.getActive()) {
									_plot_area.setGridRowMajor();
								} else {
									_plot_area.setGridColMajor();
								}
								_box.queueDraw();
							} );
		_radio_colmajor = new RadioButton("13\n24");
		_radio_colmajor.joinGroup(_radio_rowmajor);

		auto _grid_autoscale_y_label = new Label("autoscale Y        ");
		auto _check_grid_autoscale_y = new CheckButton();
		_check_grid_autoscale_y.addOnToggled(
							delegate void(ToggleButton button) {
								//writeln("overlay button toggled ", button.getActive(), "\r");
								_plot_area.setGridAutoscaleY(button.getActive());
								_box.queueDraw();
							} );

		auto logx_label = new Label("logX");
		_check_logx = new CheckButton();
		auto logy_label = new Label("logY");
		_check_logy = new CheckButton();
		auto logz_label = new Label("logZ");
		_check_logz = new CheckButton();



		auto layout_box = new Box(GtkOrientation.HORIZONTAL,0);
		layout_box.add(_radio_overlay);
		layout_box.add(_radio_grid);
		layout_box.add(_spin_columns);
		layout_box.add(columns_label);
		layout_box.add(_radio_rowmajor);
		layout_box.add(_radio_colmajor);
		layout_box.add(_check_grid_autoscale_y);
		layout_box.add(_grid_autoscale_y_label);
		layout_box.add(_check_logx);
		layout_box.add(logx_label);
		layout_box.add(_check_logy);
		layout_box.add(logy_label);
		layout_box.add(_check_logz);
		layout_box.add(logz_label);
		//_radio_overlay.show();
		//_radio_grid.show();
		//_spin_rows.show();

		_box.add(layout_box);

		add(_box);
		showAll();
	}

	Application _application;

	Box _box;
	RadioButton _radio_overlay, _radio_grid;
	SpinButton _spin_columns;
	RadioButton _radio_rowmajor, _radio_colmajor;
	CheckButton _check_logx, _check_logy, _check_logz;


	PlotArea  _plot_area;
	TreeStore _treestore;
	TreeView  _treeview;
	string[] _items; // the session items that are currently in the _treestore
	bool[string] _expanded; // safe which treeview rows are expanded
	//TreeIter[string] _folders;
	shared Session _session;
	bool _in_other_thread;

}
