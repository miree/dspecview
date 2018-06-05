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


class PlotArea : DrawingArea
{
public:
	this()
	{
		//Attach our expose callback, which will draw the window.
		addOnDraw(&drawCallback);

		// set mimium size of this Widget
		super.setSizeRequest(200,130);

		super.addOnMotionNotify(&onMotionNotify);
		super.addOnButtonPress(&onButtonPressEvent);
		super.addOnButtonRelease(&onButtonReleaseEvent);
		super.addOnScroll(&onScrollEvent);

		auto f = new File("hist.dat");
		import std.array;
		import std.conv;
		foreach(line; f.byLine)	{
			foreach(number; split(line.dup(), " ")) {
				if (number.length > 0)
					hist1 ~= to!double(number);
			}
		}
	}

	override void getPreferredHeightForWidth(int width, out int minimumHeight, out int naturalHeight)
	{
		minimumHeight = 200;
		naturalHeight = width*130/100;
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

		double[] xs;
		double[] ys;
		int N = 11;
		for (int i = 0; i < N; ++i)
		{
			import std.math;
			double x = 5.0*(i-N/2)/N;
			double y = exp(-x^^2);
			xs ~= x;
			ys ~= y;
		}

		foreach (row; 0.._vbox.getRows) {
			foreach (column; 0.._vbox.getColumns) {
				_vbox.update_coefficients(row, column, size.width, size.height);
				cr.save();
					//cr.setSourceRgba(0.0, 0.0, 0.0, 1.0);
					//cr.setLineWidth( 2);
					//drawBox(cr, _vbox, _vbox.getLeft(),_vbox.getBottom(), _vbox.getRight(),_vbox.getTop() );
					//cr.stroke();

					setContextClip(cr,_vbox);
					cr.setLineWidth(1);
					drawGrid(cr, _vbox, size.width, size.height);
					cr.stroke();


					cr.setSourceRgba(1.0, 0.0, 0.0, 1.0);
					cr.setLineWidth( 1);
					//drawLine(cr,_vbox, xs, ys);
					drawHistogram(cr,_vbox, 0,hist1.length, hist1);
					cr.stroke();

					cr.setSourceRgba(0.0, 0.0, 0.0, 1.0);
					cr.setLineWidth( 2);
					cr.setLineCap(cairo_line_cap_t.ROUND);
					//drawLine(cr, _vbox, -1,0, 1,0);
					//drawLine(cr, _vbox,  0,-1,0,1);
					drawBox(cr, _vbox, _vbox.getLeft(),_vbox.getBottom(), _vbox.getRight(),_vbox.getTop() );
					cr.stroke();

				cr.restore();

			}
		}



		return true;
	}

	auto _vbox = ViewBox(2,3 , -5,5,-5,5 );

	//int _rows = 5, _colums = 1;

	double m_radius = 0.40;
	double m_lineWidth = 0.065;

	double[] hist1;

}

