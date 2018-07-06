
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
import logscale;
void drawHistogram(T)(ref Scoped!Context cr, ViewBox box, double min, double max, T[] bins, bool logy = true, bool logx = false)
in {
	assert(bins.length > 0);
	assert(min < max);
} do {
	double bin_width = (max-min)/bins.length;
	double xhist = min;
	double x = box.transform_box2canvas_x(log_x_value_of(xhist,box,logx));
	double y = box.transform_box2canvas_y(log_y_value_of(bins[0],box,logy));
	cr.moveTo(x,y);
	xhist += bin_width;
	x = box.transform_box2canvas_x(log_x_value_of(xhist, box, logx));
	cr.lineTo(x,y);
	foreach(bin; bins[1..$])
	{
		y = box.transform_box2canvas_y(log_y_value_of(bin,box,logy));
		cr.lineTo(x,y);
		xhist += bin_width;
		x = box.transform_box2canvas_x(log_x_value_of(xhist, box, logx));
		cr.lineTo(x,y);
		if (log_x_value_of(xhist, box, logx) > box.getRight) {
			break;
		}
	}
}
void drawMipMapHistogram(MinMax)(ref Scoped!Context cr, ViewBox box, double min, double max, MinMax[] data, bool logy = true)
in {
	assert (data.length > 0);
	assert (min < max);
} do {
	double bin_width = (max-min)/data.length;
	double xhist = min + bin_width/2;
	foreach(idx, vline; data) {
		double vmin = log_y_value_of(vline.min, box, logy);
		double vmax = log_y_value_of(vline.max, box, logy);
		if (vmin == vmax) {
			drawHorizontalLine(cr,box, vmin, xhist+bin_width, xhist);
		} else {
			double vheight = vmax - vmin;
			auto pixel_height = box.get_pixel_height();
			//import std.stdio;
			//writeln("vheight = ", vheight, "    pixel_height = ", pixel_height, "\r");
			if (vheight < 2*pixel_height) {
				vmin -=  pixel_height;
				vmax +=  pixel_height;
			}
			drawVerticalLine(cr,box, xhist, vmin, vmax);
		}
		xhist += bin_width;
	}
}

void drawGridVertical(ref Scoped!Context cr, ViewBox box, int canvas_width, int canvas_height)
{
	import std.math;

	// vertical lines
	for( int i = 2; i >= 0; --i)
	{
		double width = box.getWidth()*1000/(canvas_width/box.getColumns());
		double oomx = 1; // order of magnitude X
		while (oomx < width) oomx *= 10;
		while (oomx > width) oomx /= 10;
		oomx /= 10;
		for (int n = 0; n < i; ++n) oomx *= 10;

		double left  = box.getLeft();
		double right = box.getRight();
		double bottom  = box.getBottom();
		double top     = box.getTop();

		double line_strength = 2*oomx/width;
		double color = (0.9-line_strength)^^2;
		cr.setLineWidth(1);
		cr.setSourceRgba(color, color, color, 1.0);

		double left_oom   = (cast(int)(left  /oomx))*oomx;
		while(left_oom < right)
		{
			drawVerticalLine(cr, box, left_oom, bottom, top);
			left_oom += oomx;
		}
		cr.stroke();
	}
}

void drawGridHorizontal(ref Scoped!Context cr, ViewBox box, int canvas_width, int canvas_height)
{
	import std.stdio;
	//writefln("horizontal grid: %s %s %s %s\r", box.getBottom, box.getTop, box.getLeft, box.getRight);
	// horizontal lines
	import std.math;
	for( int i = 2; i >= 0; --i)
	{
		double height  = box.getHeight()*1000/(canvas_height/box.getRows());
		double oomy = 1; // order of magnitude Y
		while (oomy < height) oomy *= 10;
		while (oomy > height) oomy /= 10;
		oomy /= 10;
		for (int n = 0; n < i; ++n) oomy *= 10;


		double left  = box.getLeft();
		double right = box.getRight();
		double bottom  = box.getBottom();
		double top     = box.getTop();

		double line_strength = 2*oomy/height;
		double color = (0.9-line_strength)^^2;
		cr.setSourceRgba(color, color, color, 1.0);

		double bottom_oom = (cast(int)(bottom/oomy))*oomy;
		while(bottom_oom < top)
		{
			drawHorizontalLine(cr, box, bottom_oom, left, right);
			bottom_oom += oomy;
		}
		cr.stroke();
	}	

}

void drawGridVerticalLog(ref Scoped!Context cr, ViewBox box, int canvas_width, int canvas_height)
{
	import std.math;

	// vertical lines
	double log_left = log(1);
	double log_right = log(box.getRight);
	double bottom = box.getBottom;
	double top    = box.getTop;
	while (log_left < box.getLeft) log_left += log(10);
	while (log_left > box.getLeft) log_left -= log(10);

	do {
		double color = 0.5;
		cr.setSourceRgba(color, color, color, 1.0);
		drawVerticalLine(cr, box, log_left, bottom, top);
		cr.stroke();
		color = 0.8;
		cr.setSourceRgba(color, color, color, 1.0);
		foreach(i ; 2..10) {
			drawVerticalLine(cr, box, log_left+log(i), bottom, top);
		}
		cr.stroke();
		log_left += log(10);
	} while (log_left <= box.getRight);
}

void drawGridHorizontalLog(ref Scoped!Context cr, ViewBox box, int canvas_width, int canvas_height)
{
	import std.math, std.stdio;

	// vertical lines
	double left = box.getLeft;
	double right = box.getRight;
	double log_bottom = log(1);
	double log_top    = log(box.getTop);
	while (log_bottom < box.getBottom) log_bottom += log(10);
	while (log_bottom > box.getBottom) log_bottom -= log(10);
	//writeln("bottom = ", bottom, " box.bottom = ", box.getBottom, "\r");
	do {
		double color = 0.5;
		cr.setSourceRgba(color, color, color, 1.0);
		drawHorizontalLine(cr, box, log_bottom, left, right);
		cr.stroke();
		color = 0.8;
		cr.setSourceRgba(color, color, color, 1.0);
		foreach(i ; 2..10) {
			drawHorizontalLine(cr, box, log_bottom+log(i), left, right);
		}
		cr.stroke();
		log_bottom += log(10);
	} while (log_bottom <= box.getTop);
}


void drawGridNumbersX(ref Scoped!Context cr, ViewBox box, int canvas_width, int canvas_height)
{
	import std.math;

	// x numers lines
	//for( int i = 2; i >= 0; --i)
	{
		int i = 1;
		double width = box.getWidth()*80/(canvas_width/box.getColumns());
		double oomx = 1; // order of magnitude X
		while (oomx < width) oomx *= 10;
		while (oomx > width) oomx /= 10;
		oomx /= 10;
		for (int n = 0; n < i; ++n) oomx *= 10;

		double left  = box.getLeft();
		double right = box.getRight();
		double bottom  = box.getBottom();
		double top     = box.getTop();

		double left_oom   = (cast(int)(left  /oomx))*oomx;
		//if (i == 1)
		{
			import std.stdio;
			//writeln("oomx ", oomx);
			left_oom = (cast(int)(left/oomx))*oomx;
			while(left_oom < right)
			{
				cr.setSourceRgba(0, 0, 0, 1.0);
				import std.conv;
				int number = cast(int)(round(left_oom/oomx));
				auto text = to!string(number*oomx);
				cairo_text_extents_t cte;
				// use the minus sign to get the extent
				cr.textExtents(to!string(-abs(number)*oomx),&cte);

				//writeln("number ", number);

				if (cte.width <= fabs((box.transform_box2canvas_x(0)-box.transform_box2canvas_x(oomx))) ||
					(number%5 == 0))
				{	
					cr.textExtents(to!string(number*oomx),&cte);
					cr.moveTo(box.transform_box2canvas_x(left_oom)-cte.width/2, box.transform_box2canvas_y(bottom)-cte.height/3);
					cr.showText(text);
				}
				left_oom += oomx;
			}
			cr.stroke();
		}
	}
}


void drawGridNumbersY(ref Scoped!Context cr, ViewBox box, int canvas_width, int canvas_height)
{
	import std.math;
	// y axis numers
	//for( int i = 2; i >= 0; --i)
	{
		int i = 0;
		double height  = box.getHeight()*1000/(canvas_height/box.getRows());
		double oomy = 1; // order of magnitude Y
		while (oomy < height) oomy *= 10;
		while (oomy > height) oomy /= 10;
		oomy /= 10;
		for (int n = 0; n < i; ++n) oomy *= 10;


		double left  = box.getLeft();
		double right = box.getRight();
		double bottom  = box.getBottom();
		double top     = box.getTop();

		double line_strength = 2*oomy/height;
		double color = (0.9-line_strength)^^2;
		cr.setSourceRgba(color, color, color, 1.0);

		double bottom_oom = (cast(int)(bottom/oomy))*oomy;


		//if (i == 0)
		{
			import std.stdio;
			//writeln("oomy ", oomy);
			bottom_oom = (cast(int)round(bottom/oomy))*oomy;
			while(bottom_oom < top)
			{
				cr.setSourceRgba(0, 0, 0, 1.0);

				int number = cast(int)(round(bottom_oom/oomy));
				import std.conv;
				auto text = to!string(number*oomy);
				cairo_text_extents_t cte;
				cr.textExtents(text,&cte);

				if (cte.height <= fabs((box.transform_box2canvas_y(0)-box.transform_box2canvas_y(oomy))) ||
					(number%5 == 0))
				{	
					cr.moveTo(box.transform_box2canvas_x(left), box.transform_box2canvas_y(bottom_oom)+cte.height/2);
					cr.showText(text);
				}
				bottom_oom += oomy;
			}
			cr.stroke();
		}
	}	
}


void drawGridNumbersLogX(ref Scoped!Context cr, ViewBox box, int canvas_width, int canvas_height)
{
	import std.math;

	// vertical lines
	double log_left = log(1);
	double log_right = log(box.getRight);
	double bottom = box.getBottom;
	double top    = box.getTop;
	while (log_left < box.getLeft) log_left += log(10);
	while (log_left > box.getLeft) log_left -= log(10);

	do {
		double color = 0.0;
		cr.setSourceRgba(color, color, color, 1.0);
		//drawVerticalLine(cr, box, log_left, bottom, top);
		import std.conv;
		double number = exp(log_left);
		auto text = to!string(number);
		cairo_text_extents_t cte;
		cr.textExtents(text,&cte);
		cr.moveTo(box.transform_box2canvas_x(log_left)-cte.width/2, box.transform_box2canvas_y(bottom)-cte.height/3);
		cr.showText(text);
		cr.stroke();
		cr.stroke();
		//color = 0.8;
		//cr.setSourceRgba(color, color, color, 1.0);
		//foreach(i ; 2..9) {
		//	drawVerticalLine(cr, box, log_left+log(i), bottom, top);
		//}
		//cr.stroke();
		log_left += log(10);
	} while (log_left <= box.getRight);
}

void drawGridNumbersLogY(ref Scoped!Context cr, ViewBox box, int canvas_width, int canvas_height)
{
	import std.math, std.stdio;

	// vertical lines
	double left = box.getLeft;
	double right = box.getRight;
	double log_bottom = log(1);
	double log_top    = log(box.getTop);
	while (log_bottom < box.getBottom) log_bottom += log(10);
	while (log_bottom > box.getBottom) log_bottom -= log(10);
	//writeln("bottom = ", bottom, " box.bottom = ", box.getBottom, "\r");
	do {
		double color = 0.0;
		cr.setSourceRgba(color, color, color, 1.0);
		//drawHorizontalLine(cr, box, log_bottom, left, right);
		import std.conv;
		double number = exp(log_bottom);
		auto text = to!string(number);
		cairo_text_extents_t cte;
		cr.textExtents(text,&cte);
		cr.moveTo(box.transform_box2canvas_x(left), box.transform_box2canvas_y(log_bottom)+cte.height/2);
		cr.showText(text);
		cr.stroke();
		//color = 0.8;
		//cr.setSourceRgba(color, color, color, 1.0);
		//foreach(i ; 2..9) {
		//	//drawHorizontalLine(cr, box, log_bottom+log(i), left, right);
		//}
		//cr.stroke();
		log_bottom += log(10);
	} while (log_bottom <= box.getTop);
}



