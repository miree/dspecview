

class Visualization
{
public:
	alias _main_box this;
	import gui;

	this(Tid sessionTid, bool in_other_thread, bool mode2d, Gui parantGui)
	{
		_sessionTid = sessionTid;
		_main_box = new Box(GtkOrientation.VERTICAL,0);	

		_plot_area = new PlotArea(sessionTid, in_other_thread, mode2d, parantGui);
		_main_box.add(_plot_area);
		_main_box.setChildPacking(_plot_area,true,true,0,GtkPackType.START);

		_parentGui = parantGui;

		//addEvents(EventMask.KEY_PRESS_MASK);


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
		//if (mode2d == false) _check_overlay.setActive(true);
		_check_overlay.setActive(false);



		_radio_rowmajor = new RadioButton("1 2\n3 4");
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
		_radio_colmajor = new RadioButton("1 3\n2 4");
		_radio_colmajor.joinGroup(_radio_rowmajor);

		_check_auto_refresh = new CheckButton("auto");

		_check_overview_mode = new CheckButton("over\nview");
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
									_plot_area.setFit();
								}
								_plot_area.queueDraw();
							});



		auto autoscale_label = new Label("auto\nscale");
		_check_autoscale_z = new CheckButton("Z",true);
		_check_autoscale_z.addOnToggled(
							delegate void(ToggleButton button) {
								//writeln("autoscale_z set to ", button.getActive(), "\r");
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
								if (!button.getActive()) {
									_plot_area.setFit();
								}
								_plot_area.queueDraw();
							}
			);
		_check_gridx.setActive(true);

		_check_gridy = new CheckButton("Y");
		_check_gridy.addOnToggled(
			delegate void(ToggleButton button) {
								_plot_area.setDrawGridHorizontal(button.getActive());
								if (!button.getActive()) {
									_plot_area.setFit();
								}
								_plot_area.queueDraw();
							}
			);
		_check_gridy.setActive(true);

		_check_grid_ontop = new CheckButton("top");
		_check_grid_ontop.addOnToggled(
			delegate void(ToggleButton button) {
								_plot_area.setGridOnTop(button.getActive());
								if (!button.getActive()) {
									_plot_area.setFit();
								}
								_plot_area.queueDraw();
							}
			);
		if (mode2d == true) _check_grid_ontop.setActive(true);


		_refresh_plot_area = new Button();//"refresh");
		_refresh_plot_area.setImage(new Image(StockID.REFRESH, IconSize.MENU));
		_refresh_plot_area.addOnClicked(delegate void(Button b) {
				_plot_area.refresh();
				//_plot_area.queueDraw();
			});
		_clear_plot_area = new Button();//"clear");
		_clear_plot_area.setImage(new Image(StockID.CLEAR, IconSize.MENU));
		_clear_plot_area.addOnClicked(delegate void(Button b) {
				_plot_area.clear();
				_plot_area.queueDraw();
			});


		auto layout_box = new Box(GtkOrientation.HORIZONTAL,0);

		layout_box.add(_clear_plot_area);		
		layout_box.add(new Separator(GtkOrientation.VERTICAL));

		layout_box.add(_refresh_plot_area);		
		layout_box.add(_check_auto_refresh);
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



		//_radio_overlay.show();
		//_radio_grid.show();
		//_spin_rows.show();

		auto layout_scrollwin = new ScrolledWindow();
		layout_scrollwin.setPropagateNaturalHeight(true);
		layout_scrollwin.setPropagateNaturalWidth(true);
		layout_scrollwin.add(layout_box);

		_main_box.add(layout_scrollwin); 


	}

	void set_overview(bool state) {
		_check_overview_mode.setActive(state);
	}
	void toggle_autoscale_z() {
		_check_autoscale_z.setActive(!_check_autoscale_z.getActive());
	}
	void toggle_autoscale_y() {
		_check_autoscale_y.setActive(!_check_autoscale_y.getActive());
	}
	void toggle_autoscale_x() {
		_check_autoscale_x.setActive(!_check_autoscale_x.getActive());
	}
	void set_autoscale_z(bool state) {
		_check_autoscale_z.setActive(state);
	}
	void set_autoscale_y(bool state) {
		_check_autoscale_y.setActive(state);
	}
	void set_autoscale_x(bool state) {
		_check_autoscale_x.setActive(state);
	}
	void toggle_logscale() {
		if (_plot_area.getMode2d()){
			_check_logz.setActive(!_check_logz.getActive());
		} else {
			_check_logy.setActive(!_check_logy.getActive());
		}
	}
	void set_logscaleX(bool state) {
		_check_logx.setActive(state);
	}
	void set_logscaleY(bool state) {
		_check_logy.setActive(state);
	}
	void set_logscaleZ(bool state) {
		_check_logz.setActive(state);
	}
	void setFitX() {
		_plot_area.setFitY();
	}
	void setFitY() {
		_plot_area.setFitX();
	}
	void setFit() {
		_plot_area.setFit();
		_plot_area.queueDraw();
	}
	void toggle_overlay() {
		_check_overlay.setActive(!_check_overlay.getActive());
	}
	void set_overlay(bool state) {
		_check_overlay.setActive(state);
	}
	void mark_dirty() {
		_dirty = true;
	}
	void redraw_content() {
		if (_dirty) {
			_dirty = false;
			_plot_area.queueDraw();
		}
		_refresh_in_flight = false;
	}
	import session;
	void addVisualizer(string itemname, immutable(Visualizer) visualizer) {
		_dirty = true;
		if (_plot_area.add(itemname, visualizer)) {
			if (_plot_area.length == 1) {
				if (_plot_area.getMode2d())  {
					_check_logy.setActive(false);
					_check_logz.setActive(true);
					_check_autoscale_y.setActive(false);
				} else {
					_check_logy.setActive(true);
					_check_logz.setActive(false);
					_check_autoscale_y.setActive(true);
				}
			}
		}
	}
	void remove(string itemname) {
		_dirty = true;
		_plot_area.remove(itemname);
	}

	void refresh() {
		if (!_refresh_in_flight) {
			_refresh_in_flight = true;
			// do this only if we are not _dirty to prevent redraw message flooding
			// in case the drawing is slower then the redraw request rate
			//import std.stdio;
			//writeln("refresh()\r");
			_plot_area.refresh();
		}
	}
	bool autoRefresh() {
		return _check_auto_refresh.getActive();
	}

private:
	import std.concurrency;
	Tid _sessionTid;

	import plotarea;
	PlotArea _plot_area;
	bool _dirty = false;
	bool _refresh_in_flight = false;

	Gui _parentGui;

	import gtk.CheckButton, gtk.RadioButton, gtk.SpinButton, gtk.Button, gtk.Image;
	import gtk.Label, gtk.Separator, gtk.ToggleButton, gtk.ScrolledWindow;
	CheckButton _check_overview_mode;
	CheckButton _check_auto_refresh;
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

public:
	import gtk.Box, gtk.Button;
	Box _main_box;	
}

