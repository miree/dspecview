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
		if (_vbox.translating.active)
		{
			_vbox.translate_ongoing(event_motion.x, event_motion.y);
			queueDrawArea(0,0, size.width, size.height);
		}
		if (_vbox.scaling.active)
		{
			_vbox.scale_ongoing(event_motion.x, 
								event_motion.y);
			queueDrawArea(0,0, size.width, size.height);
		}
		return true;
	}
	bool onButtonPressEvent(GdkEventButton *event_button, Widget w)
	{
		GtkAllocation size;
		getAllocation(size);
		writeln("PlotArea button pressed ", event_button.x, " ", event_button.y, " ", event_button.button);
		if (event_button.button == 2) // starte Translation
		{
			with(_vbox.translating)
			{
				active  = true;
				x_start = event_button.x;
				y_start = event_button.y;
			}
		}		
		if (event_button.button == 3) // starte Scaling
		{
			writeln("reducing x coordinate: ", _vbox.reduce_canvas_x(event_button.x,size.width));
			writeln("reducing y coordinate: ", _vbox.reduce_canvas_y(event_button.y,size.height));
			with(_vbox.scaling)
			{
				active  = true;
				x_start = event_button.x;//_vbox.reduce_canvas_x(event_button.x,size.width);
				y_start = event_button.y;//_vbox.reduce_canvas_y(event_button.y,size.height);
				// calculate the starting point as if it would have happened inside the top left tile
				_vbox.update_coefficients(0, 0, size.width, size.height);
				x_start_box = _vbox.transform_canvas2box_x(_vbox.reduce_canvas_x(event_button.x,size.width));
				y_start_box = _vbox.transform_canvas2box_y(_vbox.reduce_canvas_y(event_button.y,size.height));
			}
		}
		return true;
	}
	bool onButtonReleaseEvent(GdkEventButton *event_button, Widget w)
	{
		GtkAllocation size;
		getAllocation(size);
		writeln("PlotArea button released ", event_button.x, " ", event_button.y, " ", event_button.button);
		if (event_button.button == 2) 
		{
			if (_vbox.translating.active)
			{
				_vbox.translate_finish(event_button.x, event_button.y);
			}
			_vbox.translating.active = false;
			queueDrawArea(0,0, size.width, size.height);
		}
		if (event_button.button == 3) // starte Scaling
		{
			if (_vbox.scaling.active)
			{
				_vbox.scale_finish(event_button.x, event_button.y);
			}
			_vbox.scaling.active = false;
		}

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
					cr.setSourceRgba(0.0, 0.0, 0.0, 1.0);
					cr.setLineWidth( 2);
					drawBox(cr, _vbox, _vbox.getLeft(),_vbox.getBottom(), _vbox.getRight(),_vbox.getTop() );
					cr.stroke();

					setContextClip(cr,_vbox);
					cr.setLineWidth(1);
					drawGrid(cr, _vbox, size.width, size.height);
					cr.stroke();


					cr.setSourceRgba(1.0, 0.0, 0.0, 1.0);
					cr.setLineWidth( 4);
					//drawLine(cr,_vbox, xs, ys);
					drawHistogram(cr,_vbox, -5,5, ys);
					cr.stroke();

					cr.setSourceRgba(0.0, 0.0, 0.0, 1.0);
					cr.setLineWidth( 2);
					cr.setLineCap(cairo_line_cap_t.ROUND);
					drawLine(cr, _vbox, -1,0, 1,0);
					drawLine(cr, _vbox,  0,-1,0,1);
					drawBox(cr, _vbox, _vbox.getLeft(),_vbox.getBottom(), _vbox.getRight(),_vbox.getTop() );
					cr.stroke();

				cr.restore();

			}
		}

		//cr.save();
		//	cr.setSourceRgba(0.0, 0.0, 0.0, 0.8);
		//	cr.fillPreserve();
		//cr.restore();

		//cr.save();
		//	cr.setSourceRgba(1.0, 1.0, 1.0, 1.0);
		//	cr.setLineWidth( m_lineWidth * 1.7);
		//	cr.strokePreserve();
		//	cr.clip();
		//cr.restore();


		////clock ticks

		//// draw a little dot in the middle
		//cr.arc(0, 0, m_lineWidth / 3.0, 0, 2 * PI);
		//cr.fill();

		return true;
	}

	auto _vbox = ViewBox(3,3 , -5,5,-5,5 );

	//int _rows = 5, _colums = 1;

	double m_radius = 0.40;
	double m_lineWidth = 0.065;

}

