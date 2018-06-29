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
	this(shared Session session, bool in_other_thread)
	{
		_session = session;
		_in_other_thread = in_other_thread;
		//Attach our expose callback, which will draw the window.
		addOnDraw(&drawCallback);

		// set mimium size of this Widget
		super.setSizeRequest(200,130);

		super.addOnMotionNotify(&onMotionNotify);
		super.addOnButtonPress(&onButtonPressEvent);
		super.addOnButtonRelease(&onButtonReleaseEvent);
		super.addOnScroll(&onScrollEvent);

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
	}

	override void getPreferredHeightForWidth(int width, out int minimumHeight, out int naturalHeight)
	{
		minimumHeight = 200;
		naturalHeight = width*130/100;
	}

	void setOverlay() {
		_overlay = true;
	}
	void setGrid(int columns) {
		_overlay = false;
		_columns = columns;
	}

	void setGridRowMajor() {
		_row_major = true;
	}
	void setGridColMajor() {
		_row_major = false;
	}
	void setGridAutoscaleY(bool autoscale) {
		_grid_autoscale_y = autoscale;
	}

	void setFit() {
		writeln("setFit()");
		double global_top, global_bottom, global_left, global_right;
		synchronized {
			foreach(idx, drawable; _drawables) {
				auto item = _session.getDrawable(drawable);
				item.refresh();
				import std.algorithm;
				if (idx == 0) {
					global_bottom = item.getBottom();
					global_top 	  = item.getTop();
					global_left   = item.getLeft();
					global_right  = item.getRight();
				}
				global_bottom = min(global_bottom, item.getBottom());
				global_top 	  = max(global_top 	 , item.getTop());
				global_left   = min(global_left  , item.getLeft());
				global_right  = max(global_right , item.getRight());
			}
		}
		double height = global_top - global_bottom;
		_vbox._left   = global_left;
		_vbox._right  = global_right;
		_vbox._bottom = global_bottom - 0.1*height ;
		_vbox._top    = global_top    + 0.1*height;
		writeln("setFit() done ", global_left, global_right, global_top, global_bottom);
	}

	@property bool isEmpty() {
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
			case GdkScrollDirection.UP: 
				_vbox.scale_one_step(event_scroll.x, event_scroll.y, size.width, size.height, delta, delta);
			break;
			case GdkScrollDirection.DOWN:	
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

	void add_bottom_top_margin(ref double bottom, ref double top) {
		double margin_factor = 0.1;
		double height = top - bottom;
		top    += margin_factor * height;
		bottom -= margin_factor * height;
	}
	void default_bottom_top(out double bottom, out double top) {
		bottom = -10;
		top    =  10;
	}
	void draw_content_autoscale_y(ref Scoped!Context cr, ulong color_idx, ulong drawable_idx, int row, int column, int width, int height) {
		synchronized {
				double global_top = 10, global_bottom = -10;
				bool first_assignment = true;
				if (_overlay) {
					foreach(drawable; _drawables) {
						double bottom, top;
						if (_session.getDrawable(drawable).getBottomTopInLeftRight(bottom, top, _vbox.getLeft, _vbox.getRight)) {
							import std.algorithm;
							if (first_assignment) {
								global_bottom = bottom;
								global_top    = top;
								first_assignment = false;
							}
							global_bottom = min(global_bottom, bottom);
							global_top    = max(global_top   , top);
						}
					}
					add_bottom_top_margin(global_bottom, global_top);
				}

				shared Drawable drawable;
				if (_drawables.length > drawable_idx) {
					drawable = _session.getDrawable(_drawables[drawable_idx]);
				}
				double bottom      = _vbox.getBottom;
				double bottom_safe = _vbox.getBottom;
				double top         = _vbox.getTop;
				double top_safe    = _vbox.getTop;
				double delta_y = _vbox._delta_y;
				double scale_y = _vbox._scale_y;

				// safe the vbox extents in grid mode in case of autoscaling
				if (!_overlay) { 
					if (_drawables.length > drawable_idx && 
						drawable.getBottomTopInLeftRight(bottom, top, _vbox.getLeft, _vbox.getRight)) {
						add_bottom_top_margin(bottom, top);
					} else {
						default_bottom_top(bottom, top);
					}
				} else {
					bottom = global_bottom;
					top    = global_top;
				}
				_vbox._bottom = bottom;
				_vbox._top = top;
				_vbox._delta_y = 0;
				_vbox._scale_y = 1;

				_vbox.update_coefficients(row, column, width, height);
				cr.save();
					if (drawable_idx == 0 || !_overlay) { 
						// draw a grid
						setContextClip(cr,_vbox);
						cr.setLineWidth(1);
						drawGrid(cr, _vbox, width, height);
						cr.stroke();
					}
					// draw the content
					if (_drawables.length > drawable_idx) {
						color_idx %= _color_table.length;
						cr.setSourceRgba(_color_table[color_idx][0], _color_table[color_idx][1], _color_table[color_idx][2], 1.0);
						cr.setLineWidth( 2);
						drawable.draw(cr, _vbox);
						cr.stroke();
					}
					if (drawable_idx == _drawables.length-1 || !_overlay) { // in case we do overlay, we have to draw the numbers only once
						// draw a box and the grid numbers
						cr.setSourceRgba(0.4, 0.4, 0.4, 1.0);
						cr.setLineWidth( 3);
						cr.setLineCap(cairo_line_cap_t.ROUND);
						//drawLine(cr, _vbox, -1,0, 1,0);
						//drawLine(cr, _vbox,  0,-1,0,1);
						drawBox(cr, _vbox, _vbox.getLeft(),_vbox.getBottom(), _vbox.getRight(),_vbox.getTop() );
						cr.stroke();
						drawGridNumbers(cr, _vbox, width, height);
						cr.stroke();
					}
				cr.restore();

				//if (!_overlay) { // in case we do overlay, we have to draw the numbers only once
				//	//_vbox._bottom = bottom_safe;
				//	//_vbox._top    = top_safe;
				//	//_vbox._delta_y = delta_y;
				//	//_vbox._scale_y = scale_y;
				//}

//			}
		}
	}

	void draw_content(ref Scoped!Context cr, ulong color_idx, ulong drawable_idx, int row, int column, int width, int height) {
		_vbox.update_coefficients(row, column, width, height);
		cr.save();
			if (drawable_idx == 0 || !_overlay) { // in case we do overlay, we have to draw the grid only once
				// draw a grid
				setContextClip(cr,_vbox);
				cr.setLineWidth(1);
				drawGrid(cr, _vbox, width, height);
				cr.stroke();
			}
			// draw the content
			color_idx %= _color_table.length;
			cr.setSourceRgba(_color_table[color_idx][0], _color_table[color_idx][1], _color_table[color_idx][2], 1.0);
			cr.setLineWidth( 2);
			synchronized {
				if (_drawables.length > drawable_idx) {
					auto drawable = _session.getDrawable(_drawables[drawable_idx]);
					drawable.draw(cr, _vbox);
				}
			}
			cr.stroke();
			if (_drawables.length == 0 || drawable_idx == _drawables.length-1 || !_overlay) { // in case we do overlay, we have to draw the numbers only once
				// draw a box and the grid numbers
				cr.setSourceRgba(0.4, 0.4, 0.4, 1.0);
				cr.setLineWidth( 3);
				cr.setLineCap(cairo_line_cap_t.ROUND);
				//drawLine(cr, _vbox, -1,0, 1,0);
				//drawLine(cr, _vbox,  0,-1,0,1);
				drawBox(cr, _vbox, _vbox.getLeft(),_vbox.getBottom(), _vbox.getRight(),_vbox.getTop() );
				cr.stroke();
				drawGridNumbers(cr, _vbox, width, height);
				cr.stroke();
			}
		cr.restore();
	}

	//Override default signal handler:
	bool drawCallback(Scoped!Context cr, Widget widget)
	{
		// This is where we draw on the window
		GtkAllocation size;
		getAllocation(size);

		cr.save();
			cr.setSourceRgba(0.9, 0.9, 0.9, 1);   
			cr.paint();
		cr.restore();

		if (_overlay) {
			_vbox._rows = 1;
			_vbox._columns = 1;
			import std.algorithm;
			foreach (idx; 0..max(1, _drawables.length)) {
				ulong color_idx = idx;
				if (_grid_autoscale_y) {
					draw_content_autoscale_y(cr, color_idx, idx, 0, 0, size.width, size.height);
				} else {
					draw_content(cr, color_idx, idx, 0, 0, size.width, size.height);
				}
			}
		} else { // grid mode
			int rows = 1;
			while (_columns * rows < _drawables.length) {
				++rows;
			}
			_vbox._rows    = rows;
			_vbox._columns = _columns;
			foreach (row; 0.._vbox.getRows) {
				foreach (column; 0.._vbox.getColumns) {
					ulong idx = column * rows + row;
					if (_row_major) {
						idx = row * _columns + column;
					}
					ulong color_idx = idx; // same color as in overlay mode
					//ulong color_idx = 0; // same color for all in grid mode
					if (_grid_autoscale_y) {
						draw_content_autoscale_y(cr, color_idx, idx, cast(int)row, cast(int)column, size.width, size.height);
					} else {
						draw_content(cr, color_idx, idx, cast(int)row, cast(int)column, size.width, size.height);
					}
				}
			}
		}


		if (_in_other_thread) {
			import gtkc.cairo;
			cairo_destroy(cr.payload.getContextStruct());
		}
		return true;
	}

	auto _vbox = ViewBox(1,1 , -5,5,-5,5 );
	bool _overlay = true;
	int _columns = 1;

	bool _row_major = true;

	bool _grid_autoscale_y = false;


	bool _in_other_thread = false;

	//int _rows = 5, _colums = 1;

	double m_radius = 0.40;
	double m_lineWidth = 0.065;

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

