import std.stdio;
import std.string;
import std.algorithm;
import std.array;

import gio.Application : GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Window;
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

class PlotWindow : ApplicationWindow
{


	this(Application application, shared Session session, bool in_other_thread)
	{
		_session = session;
		import std.stdio;
		super(application);		
		setTitle("gtkD Plot Window");
		setDefaultSize( 300, 500 );

		_box = new Box(GtkOrientation.VERTICAL,0);

		_plot_area = new PlotArea(_session, in_other_thread);
		_box.add(_plot_area);
		//plot_area.setSizeRequest(200,200);
		_box.setChildPacking(_plot_area,true,true,0,GtkPackType.START);
		_plot_area.show();

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

		auto scrollwin = new ScrolledWindow();
		scrollwin.setPropagateNaturalHeight(true);
		scrollwin.add(layout_box);
		_box.add(scrollwin); 
//		_box.add(layout_box);

		add(_box);
		showAll();
	}

	Box _box;
	RadioButton _radio_overlay, _radio_grid;
	SpinButton _spin_columns;
	RadioButton _radio_rowmajor, _radio_colmajor;
	CheckButton _check_logx, _check_logy, _check_logz;


	PlotArea  _plot_area;
	//TreeIter[string] _folders;
	shared Session _session;


}