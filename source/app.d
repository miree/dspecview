/**
 * main.d
 *
 * A gtkD main window that uses the clock widget from clock.d
 *
 * Based on the Gtkmm example by:
 * Jonathon Jongsma
 *
 * and the original GTK+ example by:
 * (c) 2005-2006, Davyd Madeley
 *
 * Authors:
 *   Jonas Kivi (D version)
 *   Jonathon Jongsma (C++ version)
 *   Davyd Madeley (C version)
 */

module main;

import std.stdio;

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
//import gtk.TreePath;
import gtk.CellRendererText;
import gdk.Event;
import gtk.Widget;
import gtk.Menu;
import gtk.MenuItem;

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

int main(string[] args)
{
	Application application;

	void activateClock(GioApplication app)
	{
		ApplicationWindow win = new ApplicationWindow(application);

		win.setTitle("gtkD Spectrum Viewer");
		win.setDefaultSize( 250, 250 );


		auto b1 = new Button("Hallo"); b1.addOnClicked(button => say_hello(button));
		auto box = new Box(GtkOrientation.VERTICAL,0);

		auto treestore = new TreeStore([GType.STRING,GType.STRING]);
		auto treeview = new TreeView(treestore);
		auto b2 = new Button("clear");  b2.addOnClicked(button => treestore.clear());
		// add all column data
		auto renderer = new CellRendererText;
		//  compact way of addin a column
		treeview.appendColumn(new TreeViewColumn("Name", renderer, "text", 0));
		treeview.appendColumn(new TreeViewColumn("Type", renderer, "text", 1)); 

		treeview.getSelection().setMode(GtkSelectionMode.MULTIPLE);


		// create the popup menu content
		auto popup_menu = new Menu;
		//popup_menu.append(new MenuItem((MenuItem)=>writeln("selected: ", treeview.getSelectedIter().getValueString(0)), "show",    "in new window"));
		//popup_menu.append(new MenuItem((MenuItem)=>writeln("delete ", treeview.getSelectedIter().getValueString(0), " ", treestore.remove(treeview.getSelectedIter())),  "delete",  "delete the item"));
		popup_menu.append( new MenuItem(
								delegate(MenuItem m) { // the action to perform if that menu entry is selected
									write("show: ");
									auto iter = treeview.getSelectedIter();
									if (iter is null) {
										writeln("nothing selected");
									} else {
										string get_full_name(TreeIter iter) {
											auto parent = iter.getParent();
											if (parent is null) {
												return iter.getValueString(0);
											} else {
												return get_full_name(parent) ~ "/" ~ iter.getValueString(0);
											}
										}
										writeln(get_full_name(iter));
									}
								},
								"show", // menu entry label
								"show in new window"// description
							));
		popup_menu.append( new MenuItem(
								delegate(MenuItem m) { // the action to perform if that menu entry is selected
									writeln("show all: ");
									auto iters = treeview.getSelectedIters();
									foreach(iter; iters)
									{
										string get_full_name(TreeIter iter) {
											auto parent = iter.getParent();
											if (parent is null) {
												return iter.getValueString(0);
											} else {
												return get_full_name(parent) ~ "/" ~ iter.getValueString(0);
											}
										}
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
										auto iter = treeview.getSelectedIter();
										if (iter is null) {
											writeln("nothing selected");
											//break;
										} else {
											writeln(iter.getValueString(0));
											treestore.remove(iter);
										}
									//}
								}, 
								"delete",  // menu entry label
								"delete selected item" // description
							));

		treeview.addOnButtonPress(
			//(GdkEventButton* e, Widget w)=>on_button_press_event(e,w) // explicit function call
			delegate bool(GdkEventButton* e, Widget w) {
				w.onButtonPressEvent(e); 
				if (e.button == 3)	{
					popup_menu.popup(e.button, e.time);
					popup_menu.showAll(); 
				}
				writeln("button press event"); 
				return true;
			} //anonymous function
			//(GdkEventButton* e, Widget w)=>w.onButtonPressEvent(e) // shortcut lambda syntax only works for function with a single return statement
			);




		// create the tree view content
		auto top = treestore.createIter; // toplevel of the tree
		treestore.set(top, [0,1], ["WeltA","WeltB"]);
		top = treestore.append(null); // append(null) creates a new row that is NO child of the previous row
		treestore.set(top, [0,1], ["X","Y"]);
		top = treestore.append(null); // another new row that is no child
		//auto path = new TreePath(true);
		treestore.setValue(top, 0, "Hallo"); treestore.setValue(top, 1, "Welt");
		auto child = treestore.append(top); // another row that is a child of the row to which top points
		treestore.set(child, [0,1], ["Hello10","World1"]);
		child = treestore.append(top); // another row that is a child of the row to which top points
		treestore.set(child, [0,1], ["Hello2","World2"]);
		child = treestore.append(top); // another row that is a child of the row to which top points
		treestore.set(child, [0,1], ["Hello3","World3"]);
		child = treestore.append(top); // another row that is a child of the row to which top points
		treestore.set(child, [0,1], ["Hello4","World4"]);


		
		// add buttons 
		box.add(b1);
		box.add(b2);

		// add the treeview ...
		//    ... with scrolling
		auto scrollwin = new ScrolledWindow();
		scrollwin.setPropagateNaturalHeight(true);
		scrollwin.add(treeview);
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
		treeview.show();


		win.add(box);
		win.showAll();
	}

	application = new Application("org.gtkd.demo.cairo.clock", GApplicationFlags.FLAGS_NONE);
	application.addOnActivate(&activateClock);
	return application.run(args);
}

