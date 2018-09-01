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

class ImmuBuffer
{
	this(immutable(Drawable) d) {
	}
	void put(immutable(Drawable) d) {
		buffer.length = 0;
		buffer ~= d;
	}
	immutable(Drawable) get() {
		if (buffer.length == 1) {
			return buffer[0];
		}
		throw new Exception("no object stored in this ImmuBuffer");
	}
private:
	immutable(Drawable)[] buffer;	
}


bool on_button_press_event(GdkEventButton* e, Widget w)
{
	// do whatever we want
	writeln("button press event");

	return w.onButtonPressEvent(e); // forward the event to widget to get the default action
}

Gui[] gui_windows;

extern(C) nothrow static int threadIdleProcess(void* data) {
	//Don't let D exceptions get thrown from function
	try{
		import std.concurrency;
		import std.variant : Variant;
		import std.datetime;
		// get messages from parent thread
		//writeln("*************blub");
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
			writeln("thisTid: ",thisTid," tick",++cnt,"\r");
			second_cnt = 0;
			// now do the "per second" business
			//Gui gui = cast(Gui)data;
			foreach(gui; gui_windows){
				gui.updateSession();
				gui._plot_area.refresh();
				gui._plot_area.queueDraw();
			}
		}
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
		writeln("hello button_clicked ", button.getLabel());
	}
	void new_window(Button button,bool control_area, bool view_area)
	{
		auto child_window = new Gui(_application, _session, _in_other_thread, control_area, view_area);
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

	this(Application application, shared Session session, bool in_other_thread, bool show_treeview_side = true, bool show_plotarea_side = false, bool mode2d = false)
	{
		gui_windows ~= this;
		_session = session;
		_in_other_thread = in_other_thread;
		import std.stdio;
		
		super(application);
		_application = application;


		//addEvents(EventMask.KEY_PRESS_MASK);
		addOnKeyPress(delegate bool(GdkEventKey* e, Widget w) { // the action to perform if that menu entry is selected
							//writeln("key press: ", e.keyval, "\r");
							switch(e.keyval) {
								case 'f':
									_plot_area.setFitX();
									_plot_area.setFitY();
									_plot_area.queueDraw();
								break;
								case 'z':
									_check_autoscale_z.setActive(!_check_autoscale_z.getActive());
								break;
								case 'y':
									_check_autoscale_y.setActive(!_check_autoscale_y.getActive());
								break;
								case 'x':
									_check_autoscale_x.setActive(!_check_autoscale_x.getActive());
								break;
								case 'l':
									if (_plot_area.getMode2d()){
										_check_logz.setActive(!_check_logz.getActive());
									} else {
										_check_logy.setActive(!_check_logy.getActive());
									}
								break;
								case 'g':
									//if (_radio_overlay.getActive()) {
									//	_radio_grid.setActive(true);
									//}
									//else {
									//	_radio_overlay.setActive(true);
									//}
									_check_overlay.setActive(!_check_overlay.getActive());
								break;
								default:
							}
							return true;
						});

		setTitle("gtkD Spectrum Viewer");
		setDefaultSize( 300, 300 );

		_box = new Box(GtkOrientation.VERTICAL,0);
		_view_box = new Box(GtkOrientation.VERTICAL,0);

		_treestore = new TreeStore([GType.STRING,GType.STRING]);
		_treeview = new TreeView(_treestore);
		_treeview.enableModelDragSource(ModifierType.BUTTON1_MASK, null, DragAction.LINK);

		auto b00 = new Button("hide PlotArea");
			 b00.addOnClicked(delegate void(Button b) {
				_view_box.hide();
				//this.resize(100,this.getHeight());
				//_main_box.setChildPacking(_box,true,true,0,GtkPackType.START);
				});

		auto b0 = new Button("new win"); 
		     b0.addOnClicked(button => new_window(button,true,true));
		auto b0p = new Button("new plot win"); 
		     b0p.addOnClicked(button => new_window(button,false,true));
		auto b0c = new Button("new control win"); 
		     b0c.addOnClicked(button => new_window(button,true,false));

		auto b1 = new Button("open hist1"); 
		b1.addOnClicked(delegate void(Button b) {
				import gtk.FileChooserNative;
				import gtk.FileChooserDialog;
				import std.file;
				import std.string;
				auto file_chooser = new FileChooserNative(
											"open file",
											this,
											GtkFileChooserAction.OPEN,
											"open", "cancel");
				//writeln("result of file_chooser.run() = ", 
				if (ResponseType.ACCEPT == file_chooser.run()) {
					//writeln(getcwd(), ": file_chooser filename: ", , "\r");
					auto filename = file_chooser.getFilename().chompPrefix(getcwd()~"/"); 
					filename = filename.chompPrefix("/");
					writeln("filename = " , filename, "\r");
					synchronized {
						import hist1;
						auto treeview_name = filename;
						_session.addItem(treeview_name, new shared Hist1Visualizer(treeview_name, new shared Hist1Filesource(filename)));
						foreach(gui; gui_windows) {
							gui.updateSession();
						}
					}
				}
			});
		//     //b1.addOnClicked(button => say_hello(button));
		//auto b11 = new Button("open hist2"); 
		//b11.addOnClicked(delegate void(Button b) {
		//		import gtk.FileChooserNative;
		//		import gtk.FileChooserDialog;
		//		import std.file;
		//		import std.string;
		//		auto file_chooser = new FileChooserNative(
		//									"open file",
		//									this,
		//									GtkFileChooserAction.OPEN,
		//									"open", "cancel");
		//		//writeln("result of file_chooser.run() = ", 
		//		if (ResponseType.ACCEPT == file_chooser.run()) {
		//			//writeln(getcwd(), ": file_chooser filename: ", , "\r");
		//			auto filename = file_chooser.getFilename().chompPrefix(getcwd()~"/"); 
		//			filename = filename.chompPrefix("/");
		//			writeln("filename = " , filename, "\r");
		//			synchronized {
		//				import hist2;
		//				auto treeview_name = filename;
		//				_session.addItem(treeview_name, new shared Hist2Visualizer(treeview_name, new shared Hist2Filesource(filename)));
		//				foreach(gui; gui_windows) {
		//					gui.updateSession();
		//				}
		//			}
		//		}
		//	});

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
									//writeln("show selected: ");
									int dim_max = 0;
									auto iters = _treeview.getSelectedIters();
									import std.algorithm;
									foreach(iter; iters) {  
										string itemname = get_full_name(iter);
										auto itemlist = _session.getItemList();
										foreach(itemlistname; itemlist) {
											if (itemlistname.startsWith(itemname)) {
												writeln("itemname = " , itemname , "\r");
												auto item = _session.getItem(itemlistname);
												if (item !is null) {
													dim_max = max(dim_max, item.getDim());
												}
											}
										}
									}
									writeln("dim_max = " , dim_max, "\r");
									auto child_window = new Gui(_application, _session, _in_other_thread, false, true, dim_max == 2);
									iters = _treeview.getSelectedIters();
									foreach(iter; iters)
									{  
										string itemname = get_full_name(iter);
										auto itemlist = _session.getItemList();
										if (itemlist.canFind(itemname)) {
											child_window._plot_area.add_drawable(itemname);
										}
									}
									child_window._plot_area.setFit();
									child_window.show();
								},
								"show selected in new window", // menu entry label
								"show seleted items"// description
							));
		popup_menu.append( new MenuItem(
								delegate(MenuItem m) { // the action to perform if that menu entry is selected
									//writeln("show selected: ");
									int dim_max = 0;
									auto iters = _treeview.getSelectedIters();
									import std.algorithm;
									foreach(iter; iters) {  
										string itemname = get_full_name(iter);
										auto itemlist = _session.getItemList();
										foreach(itemlistname; itemlist) {
											if (itemlistname.startsWith(itemname)) {
												writeln("itemname = " , itemname , "\r");
												auto item = _session.getItem(itemlistname);
												if (item !is null) {
													dim_max = max(dim_max, item.getDim());
												}
											}
										}
									}
									writeln("dim_max = " , dim_max, "\r");
									auto child_window = new Gui(_application, _session, _in_other_thread, false, true, dim_max == 2);
									iters = _treeview.getSelectedIters();
									foreach(iter; iters)
									{  
										string itemname = get_full_name(iter);
										auto itemlist = _session.getItemList();
										foreach(itemlistname; itemlist) {
											if (itemlistname.startsWith(itemname)) {
												child_window._plot_area.add_drawable(itemlistname);
											}
										}
									}
									child_window._plot_area.setFit();
									child_window.show();
								},
								"show selected in new window recusive", // menu entry label
								"show seleted items"// description
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
		// maybe add the activated item to the on window plot area
		_treeview.addOnRowActivated(
				delegate void(TreePath path, TreeViewColumn col, TreeView view) {
					//writeln("addOnRowActivated() ", path.toString(), "\r");
					string expanded_row = get_full_name_from_path(path.toString(), _items);
					writeln(expanded_row, "\r");
					auto itemlist = _session.getItemList();
					//writeln(itemlist,"\r");
					//_plot_area.add_drawable(expanded_row);
					if (itemlist.canFind(expanded_row)) {
						_plot_area.add_drawable(expanded_row);
					}
					queueDraw();
					//_expanded[expanded_row] = true;
				}
			);
		_treeview.addOnCursorChanged( // add selected items to the preview plot area
				delegate void(TreeView view) {
					_preview_plot_area.clear();
					auto iters = _treeview.getSelectedIters();
					writeln("addOnCursorChanged() ", iters.length ,"\r");
					int i = 0;
					foreach(iter; iters)
					{  
						string itemname = get_full_name(iter);
						writeln(itemname, "\r");
						auto itemlist = _session.getItemList();
						//if (itemlist.canFind(itemname)) {
						//	_preview_plot_area.add_drawable(itemname);
						//}
						foreach(itemlistname; itemlist) {
							if (itemlistname.startsWith(itemname)) {
								_preview_plot_area.add_drawable(itemlistname);
								++i;
							}
						}
					}
					import std.math;
					_preview_plot_area.setGrid(cast(int)sqrt(1.0*i));
					_preview_plot_area.setAutoscaleZ(true);
					_preview_plot_area.setLogscaleZ(true);
					_preview_plot_area.setLogscaleX(false);
					_preview_plot_area.setLogscaleY(false);
					_preview_plot_area.setFit();
					queueDraw();
				}
			);



		updateSession();

		// add buttons 
		_box.add(b00);
		_box.add(b0);
		_box.add(b0p);
		_box.add(b0c);
		_box.add(b1);
		//_box.add(b11); // hist2 button
		_box.add(b2);
		_box.add(b3);

		// add the treeview ...
		//    ... with scrolling
		_treeview_scrollwin = new ScrolledWindow();
		_treeview_scrollwin.setPropagateNaturalHeight(true);
		_treeview_scrollwin.setPropagateNaturalWidth(true);
		_treeview_scrollwin.add(_treeview);
		_box.add(_treeview_scrollwin); 
		_box.setChildPacking(_treeview_scrollwin,true,true,0,GtkPackType.START);
		//    ... without scrolling
		//_box.add(treeview);

		_preview_plot_area = new PlotArea(_session, in_other_thread, false);
		_preview_plot_area.setGrid(1);
		_preview_plot_area.setPreviewMode(true);
		_preview_plot_area.setDrawGridVertical(true);
		_preview_plot_area.setDrawGridHorizontal(true);
		_box.add(_preview_plot_area);
		_box.setChildPacking(_preview_plot_area,true,true,0,GtkPackType.END);
		_preview_plot_area.show();



		_plot_area = new PlotArea(_session, in_other_thread, mode2d);
		_view_box.add(_plot_area);
		//plot_area.setSizeRequest(200,200);
		_view_box.setChildPacking(_plot_area,true,true,0,GtkPackType.START);
		_plot_area.show();

		b1.show();
		b2.show();
		_treeview.show();


		//_radio_overlay = new RadioButton("overlay");
		//_radio_overlay.addOnToggled(
		//					delegate void(ToggleButton button) {
		//						//writeln("overlay button toggled ", button.getActive(), "\r");
		//						if (button.getActive()) {
		//							_plot_area.setOverlay();
		//						} else {
		//							_plot_area.setGrid(cast(int)_spin_columns.getValue());
		//						}
		//						_plot_area.queueDraw();
		//					} );

		//_radio_grid = new RadioButton("grid");
		//_radio_grid.joinGroup(_radio_overlay);

		auto columns_label = new Label("columns");
		_spin_columns = new SpinButton(1,50,1);
		_spin_columns.addOnValueChanged(
							delegate void(SpinButton button) {
								//writeln("spin button changed ", button.getValue(), "\r");
								if (_check_overlay.getActive()) {
									_plot_area.setOverlay();
								} else {
									_plot_area.setGrid(cast(int)_spin_columns.getValue());
								}
								_plot_area.queueDraw();
							} );

		_check_overlay = new CheckButton("overlay");
		_check_overlay.addOnToggled(
							delegate void(ToggleButton button) {
								//writeln("overlay button toggled ", button.getActive(), "\r");
								if (button.getActive()) {
									_plot_area.setOverlay();
								} else {
									_plot_area.setGrid(cast(int)_spin_columns.getValue());
								}
								_plot_area.queueDraw();
							} );
		_plot_area.setGrid(cast(int)_spin_columns.getValue());
		if (mode2d == false) _check_overlay.setActive(true);



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

		auto _check_overview_mode = new CheckButton("over\nview");
		_check_overview_mode.addOnToggled(delegate void(ToggleButton button) {
								//writeln("overlay button toggled ", button.getActive(), "\r");
								bool active = button.getActive();
								_plot_area.setPreviewMode(active);
								_check_logx.setSensitive(!active);
								_check_logy.setSensitive(!active);
								_check_logz.setSensitive(!active);
								_check_autoscale_x.setSensitive(!active);
								_check_autoscale_y.setSensitive(!active);
								_check_autoscale_z.setSensitive(!active);
								_check_overlay.setSensitive(!active);
								_check_grid_ontop.setSensitive(!active);
								if (!active) {
									_plot_area.setFitX();
									_plot_area.setFitY();
								}
								_plot_area.queueDraw();
							});

		auto autoscale_label = new Label("auto\nscale");
		_check_autoscale_z = new CheckButton("Z",true);
		_check_autoscale_z.addOnToggled(
							delegate void(ToggleButton button) {
								writeln("autoscale_z set to ", button.getActive(), "\r");
								_plot_area.setAutoscaleZ(button.getActive());
								_plot_area.queueDraw();
							} );
		_check_autoscale_y = new CheckButton("Y",true);
		_check_autoscale_y.addOnToggled(
							delegate void(ToggleButton button) {
								//writeln("overlay button toggled ", button.getActive(), "\r");
								_plot_area.setAutoscaleY(button.getActive());
								_plot_area.queueDraw();
							} );
		_check_autoscale_x = new CheckButton("X",false);
		_check_autoscale_x.addOnToggled(
							delegate void(ToggleButton button) {
								//writeln("overlay button toggled ", button.getActive(), "\r");
								_plot_area.setAutoscaleX(button.getActive());
								_plot_area.queueDraw();
							} );
		if (mode2d == false) _check_autoscale_y.setActive(true);
		_check_autoscale_z.setActive(true);

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
		if (mode2d == false) _check_logy.setActive(true);

		_check_logz = new CheckButton("Z");
		_check_logz.addOnToggled(
			delegate void(ToggleButton button) {
								_plot_area.setLogscaleZ(button.getActive());
								_plot_area.queueDraw();
							}
			);
		if (mode2d == true) _check_logz.setActive(true);


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

		_check_grid_ontop = new CheckButton("top");
		_check_grid_ontop.addOnToggled(
			delegate void(ToggleButton button) {
								_plot_area.setGridOnTop(button.getActive());
								_plot_area.queueDraw();
							}
			);
		if (mode2d == true) _check_grid_ontop.setActive(true);


		_refresh_plot_area = new Button("refresh");
		_refresh_plot_area.addOnClicked(delegate void(Button b) {
				_plot_area.refresh();
				_plot_area.queueDraw();
			});
		_clear_plot_area = new Button("clear");
		_clear_plot_area.addOnClicked(delegate void(Button b) {
				_plot_area.clear();
				_plot_area.queueDraw();
			});


		auto layout_box = new Box(GtkOrientation.HORIZONTAL,0);

		layout_box.add(_refresh_plot_area);		
		layout_box.add(new Separator(GtkOrientation.VERTICAL));
		layout_box.add(_check_overview_mode);
		layout_box.add(new Separator(GtkOrientation.VERTICAL));
		layout_box.add(autoscale_label);
		layout_box.add(_check_autoscale_z);
		layout_box.add(_check_autoscale_y);
		layout_box.add(_check_autoscale_x);

		layout_box.add(new Separator(GtkOrientation.VERTICAL));
		layout_box.add(log_label);
		layout_box.add(_check_logx);
		layout_box.add(_check_logy);
		layout_box.add(_check_logz);

		layout_box.add(new Separator(GtkOrientation.VERTICAL));
		layout_box.add(grid_label);
		layout_box.add(_check_gridx);
		layout_box.add(_check_gridy);
		layout_box.add(_check_grid_ontop);

		layout_box.add(new Separator(GtkOrientation.VERTICAL));
		//layout_box.add(_radio_overlay);
		//layout_box.add(_radio_grid);
		layout_box.add(_check_overlay);
		layout_box.add(_radio_rowmajor);
		layout_box.add(_radio_colmajor);
		layout_box.add(_spin_columns);
		layout_box.add(columns_label);

		layout_box.add(new Separator(GtkOrientation.VERTICAL));
		layout_box.add(_clear_plot_area);		


		//_radio_overlay.show();
		//_radio_grid.show();
		//_spin_rows.show();

		auto layout_scrollwin = new ScrolledWindow();
		layout_scrollwin.setPropagateNaturalHeight(true);
		layout_scrollwin.setPropagateNaturalWidth(true);
		layout_scrollwin.add(layout_box);
		_view_box.add(layout_scrollwin); 

		// without scrolling
		//_view_box.add(layout_box);

		Box _main_box = new Box(GtkOrientation.HORIZONTAL,0);
		if (show_treeview_side)  {
			_main_box.add(_box);
			if (!show_plotarea_side) {
				_main_box.setChildPacking(_box,true,true,0,GtkPackType.START);
			}
		}
		if (show_plotarea_side) {
			_main_box.add(_view_box);
			_main_box.setChildPacking(_view_box,true,true,0,GtkPackType.START);
		}

		add(_main_box);
		showAll();
	}

	Application _application;

	Box _main_box, _box, _view_box;
	CheckButton _check_overlay;
	RadioButton _radio_overlay, _radio_grid;
	SpinButton _spin_columns;
	RadioButton _radio_rowmajor, _radio_colmajor;
	CheckButton _check_autoscale_z;
	CheckButton _check_autoscale_y;
	CheckButton _check_autoscale_x;
	CheckButton _check_logx, _check_logy, _check_logz;
	CheckButton _check_gridx, _check_gridy, _check_grid_ontop;
	Button _clear_plot_area, _refresh_plot_area;


	PlotArea  _preview_plot_area;
	PlotArea  _plot_area;
	TreeStore _treestore;
	TreeView  _treeview;
	ScrolledWindow _treeview_scrollwin;
	string[] _items; // the session items that are currently in the _treestore
	bool[string] _expanded; // safe which treeview rows are expanded
	//TreeIter[string] _folders;
	shared Session _session;
	bool _in_other_thread;

}
