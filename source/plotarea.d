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
import drawable;
import session;


class PlotArea : DrawingArea
{
public:

	this(shared Session session, bool in_other_thread, bool mode2d)
	{
		_mode2d = mode2d;
		_session = session;
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

		setFitY();
		setFitX();		

		super.dragDestSet(DestDefaults.ALL, null, DragAction.LINK);

		import gdk.DragContext;
		import gtk.SelectionData;
		super.addOnDragDataReceived(delegate void (DragContext drag_context, int a , int b , SelectionData data , uint c, uint d, Widget w) {
				writeln("drag data received: ", data, "\r");
			});

		//auto f = new File("hist.dat");
		//import std.array;
		//import std.conv;
		//foreach(line; f.byLine)	{
		//	foreach(number; split(line.dup(), " ")) {
		//		if (number.length > 0)
		//			hist1 ~= to!double(number);
		//	}
		//}
	}


	void add_drawable(string drawable) {
		import std.algorithm;
		if (!_drawables.canFind(drawable)) {
			_drawables ~= drawable;
		}
		update_drawable_list();
		auto item = _session.getDrawable(drawable);
		item.refresh();
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
	}
	void setLogscaleY(bool logscale) {
		_logscale_y = logscale;
		setFitY();
	}
	void setLogscaleZ(bool logscale) {
		_logscale_z = logscale;
	}
	void update_drawable_list() {
		//writeln("update_drawable_list()\n\rdrawables before : " , _drawables, "\r");
		string[] new_drawables;
		synchronized {
			foreach(drawable; _drawables) {
				if (_session.getDrawable(drawable) !is null) {
					//writeln(drawable, "\r");
					new_drawables ~= drawable;
				}
			}
		}
		//writeln("drawables after : " , new_drawables, "\r");
		_drawables = new_drawables;
	}

	void setFit() {
		setFitX();
		setFitY();
	}
	void refresh() {
		synchronized {
			foreach(idx, drawable; _drawables) {
				auto item = _session.getDrawable(drawable);
				item.refresh();
			}
		}		
	}

	void setFitX() {
		import logscale;
		update_drawable_list();
		double global_left, global_right;
		default_left_right(global_left, global_right);
		global_left = log_x_value_of(global_left, _logscale_x);
		global_right = log_x_value_of(global_right, _logscale_x);
		synchronized {
			foreach(idx, drawable; _drawables) {
				auto item = _session.getDrawable(drawable);
				//item.refresh();
				import std.algorithm;
				if (idx == 0) {
					global_left   = log_x_value_of(item.getLeft(),  _logscale_x);
					global_right  = log_x_value_of(item.getRight(), _logscale_x);
				}
				global_left   = min(global_left  , log_x_value_of(item.getLeft(),  _logscale_x));
				global_right  = max(global_right , log_x_value_of(item.getRight(), _logscale_x));
			}
		}
		_vbox._left   = global_left;
		_vbox._right  = global_right;
	}
	void setFitY() {
		import logscale;
		update_drawable_list();
		double global_top, global_bottom;
		default_bottom_top(global_bottom, global_top);
		global_top  = log_y_value_of(global_top, _logscale_y);
		global_bottom = log_y_value_of(global_bottom, _logscale_y);
		synchronized {
			foreach(idx, drawable; _drawables) {
				auto item = _session.getDrawable(drawable);
				//item.refresh();
				import std.algorithm;
				if (idx == 0) {
					global_bottom = log_y_value_of(item.getBottom(), _logscale_y);
					global_top 	  = log_y_value_of(item.getTop(),    _logscale_y);
				}
				global_bottom = min(global_bottom, log_y_value_of(item.getBottom(), _logscale_y));
				global_top 	  = max(global_top 	 , log_y_value_of(item.getTop(), _logscale_y));
			}
		}
		double height = global_top - global_bottom;
		_vbox._bottom = global_bottom ;//- 0.1*height ;
		_vbox._top    = global_top    ;//+ 0.1*height;
	}

	void clear() {
		_drawables.length = 0;
	}

	@property bool isEmpty() {
		if (_drawables is null) {
			return true;
		}
		return _drawables.length == 0;
	}

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

	//bool onKeyPressEvent(GdkEventKey *event_key, Widget w)
	//{
	//	writeln("key pressed " , event_key.keyval, "\r");
	//	return true;
	//}


	void add_bottom_top_margin(ref double bottom, ref double top) {
		if (bottom < top) {
			double margin_factor = 0.1;
			double height = top - bottom;
			top    += margin_factor * height;
			bottom -= margin_factor * height;
		} else {
			top    += 1;
			bottom -= 1;
		}
	}
	void default_bottom_top(out double bottom, out double top) {
		import logscale;
		bottom = -10;
		top    =  10;
		bottom = log_y_value_of(bottom, _logscale_y);
		top    = log_y_value_of(top, _logscale_y);

	}
	void default_left_right(out double left, out double right) {
		import logscale;
		left  = -10;
		right =  10;
		left  = log_x_value_of(left,  _logscale_x);
		right = log_x_value_of(right, _logscale_x);
	}
	bool get_global_bottom_top(out double bottom, out double top) {
		default_bottom_top(bottom, top);
		bool first_assignment = true;
		foreach(drawable; _drawables) {
			double b, t;
			if (_session.getDrawable(drawable).getBottomTopInLeftRight(b, t, _vbox.getLeft, _vbox.getRight, _logscale_y, _logscale_x)) {
				import std.algorithm;
				if (first_assignment) {
					bottom = b;
					top    = t;
					first_assignment = false;
				}
				bottom = min(bottom, b);
				top    = max(top   , t);
			}
		}
		return !first_assignment; // false if there was now drawable in the plotarea		
	}
	bool get_global_left_right(out double left, out double right) {
		default_left_right(left, right);
		bool first_assignment = true;
		foreach(drawable; _drawables) {
			double l, r;
			_session.getDrawable(drawable).getLeftRight(l, r, _logscale_y, _logscale_x);
			import std.algorithm;
			if (first_assignment) {
				left  = l;
				right = r;
				first_assignment = false;
			}
			left  = min(left,  l);
			right = max(right, r);
		}
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
		update_drawable_list();
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

		if (_overlay && !_preview_mode) {
			//writeln("overlay true\r");

			_vbox._rows = 1;
			_vbox._columns = 1;
			import std.algorithm;
			if (_autoscale_x) {
				double global_left, global_right;
				if (!get_global_left_right(global_left, global_right)) {
					default_left_right(global_left, global_right);
				}
				import logscale;
				_vbox.setLeftRight(log_x_value_of(global_left,_logscale_x), 
					               log_x_value_of(global_right,_logscale_x));
			}
			if (_autoscale_y) {
				double global_bottom, global_top;
				if (!get_global_bottom_top(global_bottom, global_top)) {
					default_bottom_top(global_bottom, global_top);
				}
				_vbox.setBottomTop(global_bottom, global_top);
			}
			_vbox.update_coefficients(0, 0, size.width, size.height);
			//writeln("setContextClip\r");
			setContextClip(cr, _vbox);
			if (_grid_ontop == false) {
				//writeln("draw_grid\r");
				draw_grid(cr, size.width, size.height);
			}
			//writeln("draw content\r");
			foreach (idx, drawable_name; _drawables) {
				ulong color_idx = idx % _color_table.length;
				cr.setSourceRgba(_color_table[color_idx][0], _color_table[color_idx][1], _color_table[color_idx][2], 1.0);
				cr.setLineWidth( 2);
				auto drawable = _session.getDrawable(drawable_name);
				if (drawable !is null) {
					//writeln("draw\r");
					drawable.draw(cr, _vbox, _logscale_y, _logscale_x, _logscale_z);
					cr.stroke();
				}
			}
			if (_grid_ontop == true) {
				//writeln("draw_grid\r");
				draw_grid(cr, size.width, size.height);
			}
			draw_box(cr);
			draw_numbers(cr, size.width, size.height);
			//if (_autoscale_x) {
			//	_vbox.release();
			//}
			//writeln("donw\r");
		} else { // grid mode
			//writeln("overlay false\r");
			bool _logscale_x_save = _logscale_x;
			bool _logscale_y_save = _logscale_y;
			bool _logscale_z_save = _logscale_z;
			bool _autoscale_x_save = _autoscale_x;
			bool _autoscale_y_save = _autoscale_y;
			bool _grid_ontop_save = _grid_ontop;

			int rows    = _row_major?1:_columns_or_rows;
			int columns = _row_major?_columns_or_rows:1;
			while (columns * rows < _drawables.length) {
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
					ulong idx = column * rows + row;
					if (_row_major) {
						idx = row * columns + column;
					}
					ulong color_idx = idx % _color_table.length; // same color as in overlay mode
					//ulong color_idx = 0; // same color for all in grid mode
					shared Drawable drawable = null;
					if (_drawables !is null && idx < _drawables.length) {
						drawable = _session.getDrawable(_drawables[idx]);
						if (_preview_mode){ // in preview mode: 1d hists are log xy, 2d hists are log z
							_autoscale_x = _autoscale_y = true;
							if (drawable.getDim() == 1) {
								_logscale_x = _logscale_y = true;
								_logscale_z = false;
								_grid_ontop = false;
							}
							if (drawable.getDim() == 2) {
								_logscale_x = _logscale_y = false;
								_logscale_z = true;
								_grid_ontop = true;
							}
						}
					}
					if (_autoscale_x) {
						// first determine the width
						double left, right;
						default_left_right(left, right);
						if (drawable !is null) {
							drawable.getLeftRight(left, right, _logscale_y, _logscale_x);
							//add_left_right_margin(left, right);
							import logscale;
							//_vbox.freeze();
							_vbox.setLeftRight(log_x_value_of(left,_logscale_x), 
								               log_x_value_of(right,_logscale_x));
						}
					}
					if (_autoscale_y) {
						// first determine the height of the view
						double bottom, top;
						default_bottom_top(bottom, top);
						if (drawable !is null) {
							drawable.getBottomTopInLeftRight(bottom, top, _vbox.getLeft, _vbox.getRight, _logscale_y, _logscale_x);
							//add_bottom_top_margin(bottom, top);
							_vbox.setBottomTop(bottom, top);
						}
					}
					_vbox.update_coefficients(row, column, size.width, size.height);
					//draw_content_autoscale_y(cr, color_idx, idx, cast(int)row, cast(int)column, size.width, size.height);
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

					if (_grid_ontop == false) {
						draw_grid(cr, size.width, size.height);
					}
					cr.setSourceRgba(_color_table[color_idx][0], _color_table[color_idx][1], _color_table[color_idx][2], 1.0);
					cr.setLineWidth( 2);
					if (drawable !is null) {
						drawable.draw(cr, _vbox, _logscale_y, _logscale_x, _logscale_z);
						cr.stroke();
					}
					if (_grid_ontop == true) {
						draw_grid(cr, size.width, size.height);
					}
					draw_box(cr);
					draw_numbers(cr, size.width, size.height);

					//if (_autoscale_x) {
					//	// first determine the width
					//	_vbox.release();
					//}

				}
			}
			_logscale_x = _logscale_x_save;
			_logscale_y = _logscale_y_save;
			_logscale_z = _logscale_z_save;
			_autoscale_x = _autoscale_x_save;
			_autoscale_y = _autoscale_y_save;
			_grid_ontop  = _grid_ontop_save;
		}

		
		//image_surface.destroy();
		//surface_pattern.destroy();

		if (_in_other_thread) {
			import gtkc.cairo;
			cairo_destroy(cr.payload.getContextStruct());
		}
		return true;
	}

	auto _vbox = ViewBox(1,1 , -5,5,-5,5 );
	bool _overlay = true;
	int _columns_or_rows = 1;

	bool _row_major = true;

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

	string[] _drawables;
	shared Session _session;

	double[3][] _color_table = [
		[0.8, 0.0, 0.0],
		[0.6, 0.6, 0.0],
		[0.6, 0.0, 0.6],
		[0.0, 0.8, 0.0],
		[0.0, 0.6, 0.6],
		[0.0, 0.0, 0.8]
		];

}

