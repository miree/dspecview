import std.stdio;
import std.math;
import std.datetime;

import glib.Timeout;

import cairo.Context;
import cairo.Surface;

import gtk.Widget;
import gtk.DrawingArea;

import ViewBox;
import DrawPrimitives;


class PlotArea : DrawingArea
{
public:
	this()
	{
		//Attach our expose callback, which will draw the window.
		addOnDraw(&drawCallback);

		// set mimium size of this Widget
		super.setSizeRequest(200,130);

		super.addOnMotionNotify(&onMotionNotify, cast(ConnectFlags)0);
	}

	override void getPreferredHeightForWidth(int width, out int minimumHeight, out int naturalHeight)
	{
		minimumHeight = 200;
		naturalHeight = width*130/100;
	}
protected:
	bool onMotionNotify(GdkEventMotion *em, Widget w)
	{
		writeln("motion detected ", em.x, " ", em.y);
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

		cr.save();
			cr.setSourceRgba(0.9, 0.9, 0.9, 0.9);   // brownish green
			cr.paint();
		cr.restore();


		cr.save();
			cr.setSourceRgba(0.0, 0.0, 0.0, 1.0);
			cr.setLineWidth( 2);
			cr.setLineCap(cairo_line_cap_t.ROUND);
			cr.moveTo(0,0);
			cr.lineTo(size.width, size.height);
			cr.stroke();
		cr.restore();

		auto vbox = ViewBox.ViewBox(-5,10,-10,5);
		int Nx = 2;
		int Ny = 3;
		foreach (nx; 0..Nx) {
			foreach (ny; 0..Ny) {
				vbox.update_coefficients(nx*size.width/Nx, size.width/Nx, ny*size.height/Ny, size.height/Ny);
				cr.save();
					cr.setSourceRgba(0.0, 0.0, 0.0, 1.0);
					cr.setLineWidth( 2);
					drawLine(cr, vbox, -1,0, 1,0);
					drawLine(cr, vbox,  0,-1,0,1);		
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


	double m_radius = 0.40;
	double m_lineWidth = 0.065;

}

