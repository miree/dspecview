
import cairo.Context;
import cairo.Surface;


import view;
// this should not be part of this struct
// before this makes sense, update_coefficients had to be called
void drawLine(ref Scoped!Context cr, ViewBox box, double x1, double y1, double x2, double y2)
{
	double x1_canvas = box.transform_box2canvas_x(x1);
	double y1_canvas = box.transform_box2canvas_y(y1);
	double x2_canvas = box.transform_box2canvas_x(x2);
	double y2_canvas = box.transform_box2canvas_y(y2);
	cr.moveTo(x1_canvas,y1_canvas);		
	cr.lineTo(x2_canvas,y2_canvas);
}

void drawHorizontalLine(ref Scoped!Context cr, ViewBox box, double y, double x1, double x2)
{
	double x1_canvas = box.transform_box2canvas_x(x1);
	double x2_canvas = box.transform_box2canvas_x(x2);
	double y_canvas = box.transform_box2canvas_y(y);
	cr.moveTo(x1_canvas,y_canvas);		
	cr.lineTo(x2_canvas,y_canvas);
}

void drawVerticalLine(ref Scoped!Context cr, ViewBox box, double x, double y1, double y2)
{
	double x_canvas = box.transform_box2canvas_x(x);
	double y1_canvas = box.transform_box2canvas_y(y1);
	double y2_canvas = box.transform_box2canvas_y(y2);
	cr.moveTo(x_canvas,y1_canvas);
	cr.lineTo(x_canvas,y2_canvas);
}

void setContextClip(ref Scoped!Context cr, ViewBox box)
{
	cr.resetClip();
	drawBox(cr,box, box.getLeft(), box.getBottom(), box.getRight(), box.getTop());
	cr.clip();
}

void drawBox(ref Scoped!Context cr, ViewBox box, double x1, double y1, double x2, double y2)
{
	double x1_canvas = box.transform_box2canvas_x(x1);
	double x2_canvas = box.transform_box2canvas_x(x2);
	double y1_canvas = box.transform_box2canvas_y(y1);
	double y2_canvas = box.transform_box2canvas_y(y2);
	cr.moveTo(x1_canvas,y1_canvas);		
	cr.lineTo(x2_canvas,y1_canvas);
	cr.lineTo(x2_canvas,y2_canvas);
	cr.lineTo(x1_canvas,y2_canvas);
	cr.lineTo(x1_canvas,y1_canvas);
}

void drawLine(ref Scoped!Context cr, ViewBox box, double[] xs, double[] ys)
in { assert(xs.length == ys.length); }
do
{
	if (xs.length > 1)
	{
		double x = box.transform_box2canvas_x(xs[0]);
		double y = box.transform_box2canvas_y(ys[0]);
		cr.moveTo(x,y);
		foreach(i; 1..xs.length)
		{
			x = box.transform_box2canvas_x(xs[i]);
			y = box.transform_box2canvas_y(ys[i]);
			cr.lineTo(x,y);
		}
	}
}