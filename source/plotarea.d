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
	this(shared Session session)
	{
		_session = session;
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
		_drawables ~= drawable;
		// think I don't need this anymore
		//if (_drawables.length > _vbox._rows) {
		//	_vbox._rows = cast(int)_drawables.length;
		//}
	}

	override void getPreferredHeightForWidth(int width, out int minimumHeight, out int naturalHeight)
	{
		minimumHeight = 200;
		naturalHeight = width*130/100;
	}

	void setOverlay() {
		_overlay = true;
	}
	void setGrid(int rows) {
		_overlay = false;
		_rows = rows;
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
			cr.setLineWidth( 1);
			synchronized {
				if (_drawables.length > drawable_idx) {
					auto drawable = _session.getDrawable(_drawables[drawable_idx++]);
					drawable.draw(cr, _vbox);
				}
			}
			cr.stroke();
			if (drawable_idx == _drawables.length-1 || !_overlay) { // in case we do overlay, we have to draw the numbers only once
				// draw a box and the grid numbers
				cr.setSourceRgba(0.0, 0.0, 0.0, 1.0);
				cr.setLineWidth( 2);
				cr.setLineCap(cairo_line_cap_t.ROUND);
				//drawLine(cr, _vbox, -1,0, 1,0);
				//drawLine(cr, _vbox,  0,-1,0,1);
				drawBox(cr, _vbox, _vbox.getLeft(),_vbox.getBottom(), _vbox.getRight(),_vbox.getTop() );
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



		//// scale to unit square and translate (0, 0) to be (0.5, 0.5), i.e. the
		//// center of the window
		//cr.scale(size.width, size.height);
		//cr.translate(0.5, 0.5);
		//cr.setLineWidth(m_lineWidth);


		// background color
		cr.save();
			cr.setSourceRgba(0.9, 0.9, 0.9, 1);   
			cr.paint();
		cr.restore();


		if (_overlay) {
			_vbox._rows = 1;
			_vbox._columns = 1;
			foreach (idx, drawable; _drawables) {
				ulong color_idx = idx;
				draw_content(cr, color_idx, idx, 0, 0, size.width, size.height);
			}
		} else {
			int columns = 1;
			while (columns * _rows < _drawables.length) {
				++columns;
			}
			_vbox._rows    = _rows;
			_vbox._columns = columns;
			foreach (row; 0.._vbox.getRows) {
				foreach (column; 0.._vbox.getColumns) {
					ulong idx = column * _rows + row;
					ulong color_idx = 0; // same color for all in grid mode
					draw_content(cr, color_idx, idx, cast(int)row, cast(int)column, size.width, size.height);
				}
			}
		}



		return true;
	}

	auto _vbox = ViewBox(1,1 , -5,5,-5,5 );
	bool _overlay = true;
	int _rows = 1;


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

