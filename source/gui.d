import std.stdio;
import std.string;
import std.algorithm;
import std.array;

import gio.Application : GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Button;
import gtk.Separator;
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

	return w.onButtonPressEvent(e); // forward the event to widget to get the default action
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
			//_items = _session.getItems().byKey().array().sort().array;
			_items = _session.getItemList();
		}
		foreach(item_fullname; _items) {
			add_item(item_fullname, _folders);
		}

		if (_items is null) {
			return;
		}
		// expand all treeview rows that were expanded before

		string[] removed_expansions;
		foreach(expanded_name; _expanded.byKey().array().sort().array)
		{
			// test if this folder is still present
			bool present = false;
			foreach(item; _items) {
				if (item.startsWith(expanded_name)) {
					present = true;
					break;
				} 
			}
			if (present) {
				string mypath = get_path_name_from_name(expanded_name, _items);
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


		//addEvents(EventMask.KEY_PRESS_MASK);
		addOnKeyPress(delegate bool(GdkEventKey* e, Widget w) { // the action to perform if that menu entry is selected
							writeln("key press: ", e.keyval, "\r");
							switch(e.keyval) {
								case 'f':
									_plot_area.setFitX();
									_plot_area.setFitY();
									_plot_area.queueDraw();
								break;
								case 'y':
									_check_grid_autoscale_y.setActive(!_check_grid_autoscale_y.getActive());
								break;
								case 'l':
									_check_logy.setActive(!_check_logy.getActive());
								break;
								case 'g':
									if (_radio_overlay.getActive()) {
										_radio_grid.setActive(true);
									}
									else {
										_radio_overlay.setActive(true);
									}
								break;
								default:
							}
							return true;
						});

		setTitle("gtkD Spectrum Viewer");
		setDefaultSize( 300, 500 );

		_box = new Box(GtkOrientation.VERTICAL,0);
		_view_box = new Box(GtkOrientation.VERTICAL,0);

		_treestore = new TreeStore([GType.STRING,GType.STRING]);
		_treeview = new TreeView(_treestore);

		auto b1 = new Button("open"); 
		b1.addOnClicked(delegate void(Button b) {
				import gtk.FileChooserNative;
				import gtk.FileChooserDialog;
				import std.file;
				import std.string;
				auto file_chooser = new FileChooserNative(
											"open file or directory",
											this,
											GtkFileChooserAction.OPEN,
											"open", "cancel");
				//writeln("result of file_chooser.run() = ", 
				if (ResponseType.ACCEPT == file_chooser.run()) {
					//writeln(getcwd(), ": file_chooser filename: ", , "\r");
					auto filename = file_chooser.getFilename().chompPrefix(getcwd()~"/"); 
					//writeln("filename = " , filename, "\r");
					synchronized {
						import hist1;
						_session.addItem(filename, new shared Hist1Visualizer(filename, new shared Hist1Filesource(filename)));
						updateSession();
					}
				}
			});
		     //b1.addOnClicked(button => say_hello(button));

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
									_plot_area.queueDraw();
								},
								"refresh", // menu entry label
								"refresh data content"// description
							));
		popup_menu.append( new MenuItem(
								delegate(MenuItem m) { // the action to perform if that menu entry is selected
									//writeln("show selected: ");
									auto iters = _treeview.getSelectedIters();
									foreach(iter; iters)
									{
										string itemname = get_full_name(iter);
										auto itemlist = _session.getItemList();
										if (itemlist.canFind(itemname)) {
											bool was_empty = _plot_area.isEmpty;
											_plot_area.add_drawable(itemname);
											if (was_empty) {
												_plot_area.setFit();
											}
										}
									}
									_plot_area.queueDraw();
								},
								"show selected", // menu entry label
								"show seleted items"// description
							));
		popup_menu.append( new MenuItem(
								delegate(MenuItem m) { // the action to perform if that menu entry is selected
									//writeln("show selected recusive: ");
									auto iters = _treeview.getSelectedIters();
									auto itemlist = _session.getItemList();
									foreach(iter; iters)
									{
										string itemname = get_full_name(iter);
										foreach(item; itemlist) {
											if (item.startsWith(itemname)) {
												_plot_area.add_drawable(item);
											}
										}
										//_plot_area.add_drawable(itemname);
									}
									_plot_area.setFit();
									_plot_area.queueDraw();
								},
								"show selected recusive", // menu entry label
								"show seleted items and all items in selected folders"// description
							));
		popup_menu.append( new MenuItem(
								delegate(MenuItem m) { // the action to perform if that menu entry is selected
									auto iters = _treeview.getSelectedIters();
									string[] delete_names;
									foreach(iter; iters) {
										delete_names ~= get_full_name(iter);
									}
									foreach(delete_name; delete_names) {
										_session.removeItem(delete_name);
									}
									updateSession();
									_plot_area.queueDraw();
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
		scrollwin.setPropagateNaturalWidth(true);
		scrollwin.add(_treeview);
		_box.add(scrollwin); 
		//    ... without scrolling
		//_box.add(treeview);

		_plot_area = new PlotArea(_session, in_other_thread);
		_view_box.add(_plot_area);
		//plot_area.setSizeRequest(200,200);
		_view_box.setChildPacking(_plot_area,true,true,0,GtkPackType.START);
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
								_plot_area.queueDraw();
							} );

		_radio_grid = new RadioButton("grid");
		_radio_grid.joinGroup(_radio_overlay);
		auto columns_label = new Label("columns");
		_spin_columns = new SpinButton(1,50,1);
		_spin_columns.addOnValueChanged(
							delegate void(SpinButton button) {
								//writeln("spin button changed ", button.getValue(), "\r");
								if (_radio_overlay.getActive()) {
									_plot_area.setOverlay();
								} else {
									_plot_area.setGrid(cast(int)_spin_columns.getValue());
								}
								_plot_area.queueDraw();
							} );
		_radio_rowmajor = new RadioButton("1 2\n34");
		_radio_rowmajor.addOnToggled(
							delegate void(ToggleButton button) {
								//writeln("overlay button toggled ", button.getActive(), "\r");
								if (button.getActive()) {
									_plot_area.setGridRowMajor();
									columns_label.setLabel("columns");
								} else {
									_plot_area.setGridColMajor();
									columns_label.setLabel("rows");
								}
								_plot_area.queueDraw();
							} );
		_radio_colmajor = new RadioButton("13\n24");
		_radio_colmajor.joinGroup(_radio_rowmajor);

		auto autoscale_label = new Label("autoscale");
		_check_grid_autoscale_y = new CheckButton("_Y",true);
		_check_grid_autoscale_y.addOnToggled(
							delegate void(ToggleButton button) {
								//writeln("overlay button toggled ", button.getActive(), "\r");
								_plot_area.setGridAutoscaleY(button.getActive());
								_plot_area.queueDraw();
							} );
		_check_grid_autoscale_y.setActive(true);

		auto log_label = new Label("  log");
		_check_logx = new CheckButton("X");
		_check_logx.addOnToggled(
			delegate void(ToggleButton button) {
								_plot_area.setLogscaleX(button.getActive());
								_plot_area.queueDraw();
							}
			);
		_check_logy = new CheckButton("Y");
		_check_logy.addOnToggled(
			delegate void(ToggleButton button) {
								_plot_area.setLogscaleY(button.getActive());
								_plot_area.queueDraw();
							}
			);
		_check_logy.setActive(true);
		_check_logz = new CheckButton("Z");
		_check_logz.addOnToggled(
			delegate void(ToggleButton button) {
								_plot_area.setLogscaleZ(button.getActive());
								_plot_area.queueDraw();
							}
			);


		auto grid_label = new Label("  grid");
		_check_gridx = new CheckButton("X");
		_check_gridx.addOnToggled(
			delegate void(ToggleButton button) {
								_plot_area.setDrawGridVertical(button.getActive());
								_plot_area.queueDraw();
							}
			);
		_check_gridx.setActive(true);
		_check_gridy = new CheckButton("Y");
		_check_gridy.addOnToggled(
			delegate void(ToggleButton button) {
								_plot_area.setDrawGridHorizontal(button.getActive());
								_plot_area.queueDraw();
							}
			);
		_check_gridy.setActive(true);



		auto layout_box = new Box(GtkOrientation.HORIZONTAL,0);
		layout_box.add(new Separator(GtkOrientation.VERTICAL));
		layout_box.add(autoscale_label);
		layout_box.add(_check_grid_autoscale_y);

		layout_box.add(new Separator(GtkOrientation.VERTICAL));
		layout_box.add(log_label);
		layout_box.add(_check_logx);
		layout_box.add(_check_logy);
		layout_box.add(_check_logz);

		layout_box.add(new Separator(GtkOrientation.VERTICAL));
		layout_box.add(grid_label);
		layout_box.add(_check_gridx);
		layout_box.add(_check_gridy);

		layout_box.add(new Separator(GtkOrientation.VERTICAL));
		layout_box.add(_radio_overlay);
		layout_box.add(_radio_grid);
		layout_box.add(_radio_rowmajor);
		layout_box.add(_radio_colmajor);
		layout_box.add(_spin_columns);
		layout_box.add(columns_label);


		//_radio_overlay.show();
		//_radio_grid.show();
		//_spin_rows.show();

		_view_box.add(layout_box);

		Box main_box = new Box(GtkOrientation.HORIZONTAL,0);
		main_box.add(_box);
		main_box.add(_view_box);
		main_box.setChildPacking(_view_box,true,true,0,GtkPackType.START);

		add(main_box);
		showAll();
	}

	Application _application;

	Box _box, _view_box;
	RadioButton _radio_overlay, _radio_grid;
	SpinButton _spin_columns;
	RadioButton _radio_rowmajor, _radio_colmajor;
	CheckButton _check_grid_autoscale_y;
	CheckButton _check_logx, _check_logy, _check_logz;
	CheckButton _check_gridx, _check_gridy;


	PlotArea  _plot_area;
	TreeStore _treestore;
	TreeView  _treeview;
	string[] _items; // the session items that are currently in the _treestore
	bool[string] _expanded; // safe which treeview rows are expanded
	//TreeIter[string] _folders;
	shared Session _session;
	bool _in_other_thread;

}
