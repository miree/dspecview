import std.stdio;
import std.math;
import std.datetime;

import glib.Timeout;

import cairo.Context;
import cairo.Surface;

import gtk.Widget;
import gdk.Event;
import gtk.DrawingArea;

import view;
import primitives;
import session;


class PlotArea : DrawingArea
{
public:

	import std.concurrency;
	import gui;
	this(Tid sessionTid, bool in_other_thread, bool mode2d, Gui parentGui)
	{
		_parentGui = parentGui;
		_mode2d = mode2d;
		//_session = session;
		_sessionTid = sessionTid;
		_in_other_thread = in_other_thread;
		//Attach our expose callback, which will draw the window.
		addOnDraw(&drawCallback);


		// set mimium size of this Widget
		super.setSizeRequest(100,50);

		super.addOnMotionNotify(&onMotionNotify);
		super.addOnButtonPress(&onButtonPressEvent);
		super.addOnButtonRelease(&onButtonReleaseEvent);
		super.addOnScroll(&onScrollEvent);

		//super.addOnKeyPress(&onKeyPressEvent); // doesn't work .... have to enable some mask on the window that holds this widget

		setFitZ();
		setFitY();
		setFitX();	


		super.dragDestSet(DestDefaults.ALL, null, DragAction.LINK);

		import gdk.DragContext;
		import gtk.SelectionData;
		super.addOnDragDataReceived(delegate void (DragContext drag_context, int a , int b , SelectionData data , uint c, uint d, Widget w) {
				writeln("drag data received: ", data, "\r");
			});
	}


	@property ulong length() {
		return _itemnames.length;
	}

	void add(string itemname, immutable(Visualizer) visualizer) 
	{
		import std.stdio;
		if (visualizer !is null && _visualizers.length == 0) {
			_mode2d = (visualizer.getDim() == 2);
		}

		auto v = (itemname in _visualizers);
		if (v is null) {
			_itemnames ~= itemname;
		}
		//writeln("_itemnames.length=",_itemnames.length,"\r");
		_visualizers[itemname].length = 0;
		_visualizers[itemname] ~= visualizer;
	}
	void remove(string removed_itemname) {
		import std.algorithm;
		string[] new_itemnames;
		foreach(itemname; _itemnames) {
			if (itemname == removed_itemname) {
				_visualizers.remove(itemname);
			} else {
				new_itemnames ~= itemname;
			}
		}
		_itemnames = new_itemnames;

	}

	override void getPreferredHeightForWidth(int width, out int minimumHeight, out int naturalHeight)
	{
		minimumHeight = 200;
		naturalHeight = width*130/100;
	}

	bool getMode2d() {
		return _mode2d;
	}
	void setOverlay() {
		_overlay = true;
	}
	void setGrid(int columns_or_rows) {
		_overlay = false;
		_columns_or_rows = columns_or_rows;
	}

	void setGridRowMajor() {
		_row_major = true;
	}
	void setGridColMajor() {
		_row_major = false;
	}
	void setAutoscaleZ(bool autoscale) {
		_autoscale_z = autoscale;
	}
	void setAutoscaleY(bool autoscale) {
		_autoscale_y = autoscale;
	}
	void setAutoscaleX(bool autoscale) {
		_autoscale_x = autoscale;
	}
	void setGridOnTop(bool ontop) {
		_grid_ontop = ontop;
	}
	void setPreviewMode(bool preview) {
		_preview_mode = preview;
	}
	void setDrawGridHorizontal(bool draw) {
		_draw_grid_horizontal = draw;
	}
	void setDrawGridVertical(bool draw) {
		_draw_grid_vertical = draw;
	}
	void setLogscaleX(bool logscale) {
		_logscale_x = logscale;
		setFitX();
		// adjust the zoom ranges for linear and logarithmic axis scaling
		if (logscale) { _vbox.setWidthMinMax(1e-2,1e2);}
		else          { _vbox.setWidthMinMax(1e-3,1e10);}
	}
	void setLogscaleY(bool logscale) {
		_logscale_y = logscale;
		setFitY();
		// adjust the zoom ranges for linear and logarithmic axis scaling
		if (logscale) { _vbox.setHeightMinMax(1e-2,1e2);}
		else          { _vbox.setHeightMinMax(1e-3,1e10);}
	}
	void setLogscaleZ(bool logscale) {
		_logscale_z = logscale;
		setFitZ();
		// adjust the zoom ranges for linear and logarithmic axis scaling
		//if (logscale) { _vbox.setHeightMinMax(1e-2,1e2);}
		//else          { _vbox.setHeightMinMax(1e-3,1e10);}
	}

	void refresh() {
		import std.stdio;
		//writeln(" plotarea.refresh()\r");
		foreach(itemname, visualizer; _visualizers) {
			//writeln("   guis[", _parentGui.getGuiIdx(),"] requests visualizer for item: ", itemname, "\r");
			_sessionTid.send(MsgRequestItemVisualizer(itemname, _parentGui.getGuiIdx()), thisTid);
		}
		_sessionTid.send(MsgEchoRedrawContent(_parentGui.getGuiIdx()), thisTid);
	}

	void setFit() {
		setFitX();
		setFitY();
		setFitZ();
	}
	void setFitX() {
		import logscale;
		//update_drawable_list();
		double global_left, global_right;
		get_global_left_right(global_left, global_right);
		_vbox._left   = global_left;
		_vbox._right  = global_right;
	}
	void setFitY() {
		import logscale;
		//update_drawable_list();
		double global_top, global_bottom;
		get_global_bottom_top(global_bottom, global_top);
		_vbox._bottom = global_bottom ;
		_vbox._top    = global_top    ;
	}
	void setFitZ() {
		import logscale;
		//update_drawable_list();
		double global_zmin, global_zmax;
		get_global_zmin_zmax(global_zmin, global_zmax);
		_vbox._zmin = global_zmin ;
		_vbox._zmax = global_zmax ;
	}

	void clear() {
		_visualizers = null;
		_itemnames.length = 0;
		//_drawables.length = 0;
	}

	//@property bool isEmpty() {
	//	if (_visualizers is null) {
	//		return true;
	//	}
	//	return _visualizers.length == 0;
	//	return true;
	//}

protected:
	bool onMotionNotify(GdkEventMotion *event_motion, Widget w)
	{
		GtkAllocation size;
		getAllocation(size);
		if (_vbox.translating.active) {
			_vbox.translate_ongoing(event_motion.x, event_motion.y);
			queueDrawArea(0,0, size.width, size.height);
		}
		if (_vbox.scaling.active) {
			_vbox.scale_ongoing(event_motion.x, event_motion.y);
			queueDrawArea(0,0, size.width, size.height);
		}
		return true;
	}

	bool onDragDataReceived(GdkEventButton *e, Widget) {
		return true;
	}

	bool onButtonPressEvent(GdkEventButton *event_button, Widget w)
	{
		GtkAllocation size;
		getAllocation(size);
		//writeln("PlotArea button pressed ", event_button.x, " ", event_button.y, " ", event_button.button);
		if (event_button.button == 2) // starte Translation
		{
			_vbox.translate_start(event_button.x, event_button.y);
		}		
		if (event_button.button == 3) // starte Scaling
		{
			_vbox.scale_start(event_button.x, event_button.y, size.width, size.height);
		}
		return true;
	}

	bool onButtonReleaseEvent(GdkEventButton *event_button, Widget w)
	{
		GtkAllocation size;
		getAllocation(size);
		//writeln("PlotArea button released ", event_button.x, " ", event_button.y, " ", event_button.button);
		if (event_button.button == 2) 
		{
			if (_vbox.translating.active) {
				_vbox.translate_finish(event_button.x, event_button.y);
			}
			queueDrawArea(0,0, size.width, size.height);
		}
		if (event_button.button == 3) // starte Scaling
		{
			if (_vbox.scaling.active) {
				_vbox.scale_finish(event_button.x, event_button.y);
			}
			queueDrawArea(0,0, size.width, size.height);
		}
		return true;
	}

	bool onScrollEvent(GdkEventScroll *event_scroll, Widget w)
	{
		GtkAllocation size;
		getAllocation(size);
		double delta = 50;
		final switch(event_scroll.direction)
		{
			import gdk.Event;
			case GdkScrollDirection.DOWN: 
				_vbox.scale_one_step(event_scroll.x, event_scroll.y, size.width, size.height, delta, delta);
			break;
			case GdkScrollDirection.UP:	
				_vbox.scale_one_step(event_scroll.x, event_scroll.y, size.width, size.height, -delta, -delta);
			break;
			case GdkScrollDirection.LEFT: 
				_vbox.translate_one_step(event_scroll.x, event_scroll.y, delta, 0);
			break;
			case GdkScrollDirection.RIGHT: 
				_vbox.translate_one_step(event_scroll.x, event_scroll.y, -delta, 0);
			break;
			case GdkScrollDirection.SMOOTH:
				// nothing yet
			break;
		}
		queueDrawArea(0,0, size.width, size.height);

		return true;
	}

	void add_zmin_zmax_margin(ref double zmin, ref double zmax, double margin_factor = 0.06) {
		if (zmin < zmax) {
			double height = zmax - zmin;
			zmax += margin_factor * height;
			zmin -= margin_factor * height;
		} else {
			//writeln("zmin=",zmin, "  zmax=",zmax,"\r");
			//assert(zmax == zmin);
			double t,b;
			default_zmin_zmax(b,t);
			zmax += t;
			zmin += b;
		}
	}	
	void add_bottom_top_margin(ref double bottom, ref double top, double margin_factor = 0.06) {
		if (bottom < top) {
			double height = top - bottom;
			top    += margin_factor * height;
			bottom -= margin_factor * height;
		} else {
			assert(top == bottom);
			double t,b;
			default_bottom_top(b,t);
			top    += t;
			bottom += b;
		}
	}	
	void add_left_right_margin(ref double left, ref double right, double margin_factor = 0.06) {
		if (left < right) {
			double height = right - left;
			right    += margin_factor * height;
			left -= margin_factor * height;
		} else {
			assert(right == left);
			double t,b;
			default_left_right(b,t);
			right    += t;
			left += b;
		}
	}
	void default_zmin_zmax(out double zmin, out double zmax) {
		import logscale;
		zmin = log_z_value_of(-10, _logscale_z);
		zmax = log_z_value_of( 10, _logscale_z);

	}
	void default_bottom_top(out double bottom, out double top) {
		import logscale;
		bottom = log_y_value_of(-10, _logscale_y);
		top    = log_y_value_of( 10, _logscale_y);

	}
	void default_left_right(out double left, out double right) {
		import logscale;
		left  = log_x_value_of(-10,  _logscale_x);
		right = log_x_value_of( 10, _logscale_x);
	}
	bool get_global_zmin_zmax(out double zmin, out double zmax) {
		default_zmin_zmax(zmin, zmax);
		bool first_assignment = true;
		foreach(key, visualizer; _visualizers) {
			if (visualizer.length == 1) {
				double mi,ma;
				if (visualizer[0].getZminZmaxInLeftRightBottomTop(mi, ma, _vbox.getLeft(), _vbox.getRight(), 
					                                                   _vbox.getBottom(), _vbox.getTop(), 
					                                                   _logscale_z, _logscale_y, _logscale_x)) {
					import std.algorithm;
					if (first_assignment) {
						zmin = mi;
						zmax = ma;
						first_assignment = false;
					}
					zmin = min(zmin, mi);
					zmax = max(zmax, ma);
				}
			}
		}		
		add_zmin_zmax_margin(zmin, zmax, 0.0); // the margin-factor of 0.0 is important to not mess up the color key numbers
		return !first_assignment; // false if there was now drawable in the plotarea		
	}
	bool get_global_bottom_top(out double bottom, out double top) {
		default_bottom_top(bottom, top);
		bool first_assignment = true;
		foreach(key, visualizer; _visualizers) {
			if (visualizer.length == 1) {
				double b,t;
				if (visualizer[0].getBottomTopInLeftRight(b,t, _vbox.getLeft, _vbox.getRight, _logscale_y, _logscale_x)) {
					import std.algorithm;
					if (first_assignment) {
						bottom = b;
						top    = t;
						first_assignment = false;
					}
					bottom = min(bottom, b);
					top    = max(top,    t);
				}
			}
		}
		add_bottom_top_margin(bottom,top);
		return !first_assignment; // false if there was now drawable in the plotarea		
	}
	bool get_global_left_right(out double left, out double right) {
		default_left_right(left, right);
		import std.stdio;
		bool first_assignment = true;
		foreach(key, visualizer; _visualizers) {
			if (visualizer.length == 1) {
				double l,r;
				if (visualizer[0].getLeftRight(l,r, _logscale_y, _logscale_x)) {
					import std.algorithm;
					if (first_assignment) {
						left  = l;
						right = r;
						first_assignment = false;
					}
					left  = min(left,  l);
					right = max(right, r);
				}
			}
		}		
		add_left_right_margin(left,right);
		return !first_assignment; // false if there was now drawable in the plotarea		
	}

	void draw_box(ref Scoped!Context cr)
	{
		cr.setLineWidth(2);
		cr.setSourceRgba(0.3, 0.3, 0.3, 1);   
		drawBox(cr, _vbox, _vbox.getLeft(),_vbox.getBottom(), _vbox.getRight(),_vbox.getTop() );
		cr.stroke();
	}
	void draw_grid(ref Scoped!Context cr, int width, int height) 
	{
		cr.setLineWidth(1);
		if (_draw_grid_horizontal) {
			if (_logscale_y) {
				drawGridHorizontalLog(cr, _vbox, width, height);
			} else {
				drawGridHorizontal(cr, _vbox, width, height);
			}
		}
		if (_draw_grid_vertical) {
			if (_logscale_x) {
				drawGridVerticalLog(cr, _vbox, width, height);
			} else {
				drawGridVertical(cr, _vbox, width, height);
			}
		}
		cr.stroke();
	}
	void draw_numbers(ref Scoped!Context cr, int width, int height) 
	{
		if (_logscale_x) {
			drawGridNumbersLogX(cr, _vbox, width, height);
		} else {
			drawGridNumbersX(cr, _vbox, width, height);
		}
		if (_logscale_y) {
			drawGridNumbersLogY(cr, _vbox, width, height);
		} else {
			drawGridNumbersY(cr, _vbox, width, height);
		}
		cr.stroke();
	}

	//Override default signal handler:
	bool drawCallback(Scoped!Context cr, Widget widget)
	{
		//writeln("drawCallback\r");
		//update_drawable_list();
		// This is where we draw on the window
		GtkAllocation size;
		getAllocation(size);

		cr.save();
			cr.setSourceRgba(0.9, 0.9, 0.9, 1);   
			cr.paint();
		cr.restore();

	//import cairo.ImageSurface;
	//auto image_surface = ImageSurface.createFromPng("my_image.png");
	////import gdk.Pixbuf;
	////auto image = new Pixbuf("my_image.png");
	//import gdk.Cairo;
	////cr.setSourcePixbuf(image, 300, 200);
	//import cairo.Pattern;
	//auto surface_pattern = Pattern.createForSurface(image_surface);
	//surface_pattern.setFilter(CairoFilter.NEAREST);
		//auto pattern = Pattern.create(image);

			//Glib::RefPtr<Gdk::Pixbuf> image = Gdk::Pixbuf::create_from_file("myimage.png");
			//  // Draw the image at 110, 90, except for the outermost 10 pixels.
			//  Gdk::Cairo::set_source_pixbuf(cr, image, 100, 80);
			//  cr->rectangle(110, 90, image->get_width()-20, image->get_height()-20);
			//  cr->fill();
			//  return true;

		auto overlay_saved = _overlay;
		auto columns_or_rows_saved = _columns_or_rows;
		if (_preview_mode) {
			_overlay = false;
			_columns_or_rows = cast(int)sqrt(1+1.0*_itemnames.length);
			if (_columns_or_rows == 0) {
				_columns_or_rows = 1;
			}
		}



		if (_overlay) {
			//writeln("overlay true\r");
			bool draw_color_key = false;
			_vbox._rows = 1;
			_vbox._columns = 1;
			import std.algorithm;
			if (_autoscale_x) {
				double global_left, global_right;
				get_global_left_right(global_left, global_right);
				import logscale;
				_vbox.setLeftRight(global_left,global_right);
			}
			if (_autoscale_y) {
				double global_bottom, global_top;
				get_global_bottom_top(global_bottom, global_top);
				_vbox.setBottomTop(global_bottom, global_top);
			}
			if (_autoscale_z) {
				double global_zmin, global_zmax;
				get_global_zmin_zmax(global_zmin, global_zmax);
				_vbox.setZminZmax(global_zmin, global_zmax);
			}
			_vbox.update_coefficients(0, 0, size.width, size.height);
			//writeln("setContextClip\r");
			setContextClip(cr, _vbox);
			if (_grid_ontop == false) {
				//writeln("draw_grid\r");
				draw_grid(cr, size.width, size.height);
			}
			//writeln("draw content\r");
			double min_color_key, max_color_key;
			import std.array, std.algorithm;
			//foreach(itemname, visualizer; _visualizers) {
			foreach(idx, itemname; _itemnames) {
				auto visualizer = _visualizers[itemname];
				if (visualizer.length == 1) {
					import primitives;
					double[3] color = getColor(visualizer[0].getColorIdx());
					cr.setSourceRgba(color[0], color[1], color[2], 1.0);
					cr.setLineWidth( 2);
					visualizer[0].draw(cr, _vbox, _logscale_y, _logscale_x, _logscale_z);
					cr.stroke();
						//if (drawable.needsColorKey()) {
						//	if (!draw_color_key) {// first assignment
						//		min_color_key = drawable.minColorKey();
						//		max_color_key = drawable.maxColorKey();
						//	} else {
						//		min_color_key = min(min_color_key, drawable.minColorKey());
						//		max_color_key = max(max_color_key, drawable.maxColorKey());
						//	}
						//	draw_color_key |= drawable.needsColorKey();
						//}
				}
			}
			if (_grid_ontop == true) {
				//writeln("draw_grid\r");
				draw_grid(cr, size.width, size.height);
			}
			draw_box(cr);
			draw_numbers(cr, size.width, size.height);
			// draw the color key;
			if (draw_color_key) {
				//drawColorKey(cr, _vbox, size.width, size.height, _logscale_z);
			}
			//writeln("done\r");
		} else { // !overlay_mode => grid mode or preview mode
			//writeln("overlay false\r");
			bool logscale_x_save = _logscale_x;
			bool logscale_y_save = _logscale_y;
			bool logscale_z_save = _logscale_z;
			bool autoscale_x_save = _autoscale_x;
			bool autoscale_y_save = _autoscale_y;
			bool autoscale_z_save = _autoscale_z;
			bool grid_ontop_save = _grid_ontop;

			int rows    = _row_major?1:_columns_or_rows;
			int columns = _row_major?_columns_or_rows:1;
			while (columns * rows < _visualizers.length) {
				if (_row_major) {
					++rows;
				} else {
					++columns;
				}
			}
			_vbox._rows    = rows;
			_vbox._columns = columns;
			foreach (row; 0.._vbox.getRows) {
				foreach (column; 0.._vbox.getColumns) {
					//writeln("row=",row, " col=",column, "\r");
					// get the index
					ulong idx = column * rows + row;
					if (_row_major) {
						idx = row * columns + column;
					}
					// check if this cell has anything drawn in it
					bool cell_has_content = (idx < _itemnames.length);
					// get itemname from index
					if (cell_has_content) {
						auto visualizer = _visualizers[_itemnames[idx]];
						if (visualizer.length != 1) {
							// should never happen in any case
							writeln("plotarea.d grid_mode drawing: this should never happen\r");
							continue;
						}
						// handle the preview mode (just a number of fixed settings on the plot_area properties)
						// in preview mode: 1d hists are log xy, 2d hists are log z
						if (_preview_mode){ 
							_autoscale_z = _autoscale_x = _autoscale_y = true;
							if (visualizer[0].getDim() == 1) {
								_logscale_x = _logscale_y = true;
								_logscale_z = false;
								_grid_ontop = false;
							}
							if (visualizer[0].getDim() == 2) {
								_logscale_x = _logscale_y = false;
								_logscale_z = true;
								_grid_ontop = false;
							}
						}
						// handle autoscaling individual items (if enabled)
						if (_autoscale_x) {
							double left, right;
							default_left_right(left, right);
							if (!visualizer[0].getLeftRight(left,right, _logscale_y, _logscale_x)) {
								default_left_right(left, right);
							}
							add_left_right_margin(left, right);
							_vbox.setLeftRight(left,right);
						}
						if (_autoscale_y) {
							double bottom, top;
							if (!visualizer[0].getBottomTopInLeftRight(bottom,top, _vbox.getLeft(), _vbox.getRight(), _logscale_y, _logscale_x)) {
								default_bottom_top(bottom, top);
							}
							add_bottom_top_margin(bottom, top);
							_vbox.setBottomTop(bottom, top);
						}
						if (_autoscale_z) {
							double zmin, zmax;
							if (!visualizer[0].getZminZmaxInLeftRightBottomTop(zmin, zmax,  _vbox.getLeft(), _vbox.getRight(), _vbox.getBottom(), _vbox.getTop(), _logscale_z, _logscale_y, _logscale_x)) {
								default_zmin_zmax(zmin, zmax);
							}
							// expand z-range to full base 10 numbers (1,10,100,1000,...)
							//if (_logscale_z) {
							//	import std.math, std.algorithm;
							//	double min = log(1);
							//	while (min < zmin) min += log(10);
							//	while (min > zmin) min -= log(10);
							//	zmin = min;

							//	double max = log(1);
							//	while (max > zmax) max -= log(10);
							//	while (max < zmax) max += log(10);
							//	zmax = max;

							//	if (zmax <= zmin) zmax += log(10);
							//}

							add_zmin_zmax_margin(zmin, zmax, 0.0); // margin factor of 0.0 is needed to not mess up the color-key numbers
							_vbox.setZminZmax(zmin, zmax);
						}

						// setup the ViewBox
						_vbox.update_coefficients(row, column, size.width, size.height);
						setContextClip(cr, _vbox);

			//cr.save();
			//cr.scale(_vbox._b_x, -_vbox._b_y);
			//cr.translate(_vbox._a_x/_vbox._b_x, - 200 -_vbox._a_y/_vbox._b_y);
			//cr.rectangle(0,0, 200,200);
			//cr.setSource(surface_pattern);

			////cr.rectangle(_vbox.transform_box2canvas_x(0.0),_vbox.transform_box2canvas_y(0.0), 
			////	         _vbox.transform_box2canvas_x(image.getWidth()), _vbox.transform_box2canvas_y(image.getHeight()));
			//cr.fill();
			//cr.restore();

						// draw the content (grid the item and numbers)
						if (_grid_ontop == false) {
							draw_grid(cr, size.width, size.height);
						}

						import primitives;
						double[3] color = getColor(visualizer[0].getColorIdx());
						cr.setSourceRgba(color[0], color[1], color[2], 1.0);

						cr.setLineWidth(2);
						visualizer[0].draw(cr, _vbox, _logscale_y, _logscale_x, _logscale_z);
						cr.stroke();

						if (_grid_ontop == true || !cell_has_content) {
							draw_grid(cr, size.width, size.height);
						}
						draw_box(cr);
						draw_numbers(cr, size.width, size.height);

						// draw the color key;
						if (visualizer[0] !is null && visualizer[0].needsColorKey()) {
							drawColorKey(cr, _vbox, size.width, size.height, _logscale_z);
						}


					} else { // if (cell_has_content)
						if (_autoscale_x) {
							double left, right;
							default_left_right(left, right);
							add_left_right_margin(left,right);
							_vbox.setLeftRight(left, right);
						}
						if (_autoscale_y) {
							double bottom, top;
							default_bottom_top(bottom, top);
							add_bottom_top_margin(bottom, top);
							_vbox.setBottomTop(bottom, top);
						}
						if (_autoscale_z) {
							double zmin, zmax;
							default_zmin_zmax(zmin, zmax);
							add_zmin_zmax_margin(zmin, zmax);
							_vbox.setZminZmax(zmin, zmax);
						}						
						_vbox.update_coefficients(row, column, size.width, size.height);
						setContextClip(cr, _vbox);
						draw_grid(cr, size.width, size.height);
						draw_box(cr);
						draw_numbers(cr, size.width, size.height);
					}


					//if (_autoscale_x) {
					//	// first determine the width
					//	_vbox.release();
					//}

					//writeln("row=",row, " col=",column, "done \r");

				}
			}
			_logscale_x = logscale_x_save;
			_logscale_y = logscale_y_save;
			_logscale_z = logscale_z_save;
			_autoscale_x = autoscale_x_save;
			_autoscale_y = autoscale_y_save;
			_autoscale_z = autoscale_z_save;
			_grid_ontop  = grid_ontop_save;


		}


		if (_preview_mode) {
			_overlay = overlay_saved;
			_columns_or_rows = columns_or_rows_saved;
		}

		
		//image_surface.destroy();
		//surface_pattern.destroy();

		if (_in_other_thread) {
			import gtkc.cairo;
			cairo_destroy(cr.payload.getContextStruct());
		}
		//writeln("Draw callback done\r");
		return true;
	}

	auto _vbox = ViewBox(1,1 , -5,5,-5,5 );
	bool _overlay = true;
	int _columns_or_rows = 1;

	bool _row_major = true;

	bool _autoscale_z = false;
	bool _autoscale_y = false;
	bool _autoscale_x = false;

	bool _logscale_x = false;
	bool _logscale_y = false;
	bool _logscale_z = false;

	bool _draw_grid_horizontal = false;
	bool _draw_grid_vertical = false;
	bool _grid_ontop = false;

	bool _in_other_thread = false;

	bool _preview_mode = false;

	//int _rows = 5, _colums = 1;

	double m_radius = 0.40;
	double m_lineWidth = 0.065;

	bool _mode2d; // optimized startup and drawing for 1d or 2d plotting

	Gui _parentGui; // from this we can get the index into the array of Gui objects (each object represents one window)

	//string[] _visualizers;
	immutable(Visualizer)[][string] _visualizers;
	string[] _itemnames;
	//string[] _drawables;
	//shared Session _session;
	import std.concurrency;
	Tid _sessionTid;

	//double[3][] _color_table = [
	//	[0.8, 0.0, 0.0],
	//	[0.6, 0.6, 0.0],
	//	[0.6, 0.0, 0.6],
	//	[0.0, 0.8, 0.0],
	//	[0.0, 0.6, 0.6],
	//	[0.0, 0.0, 0.8]
	//	];

}

