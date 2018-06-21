import item;
import view;

import cairo.Context;
import cairo.Surface;
import std.algorithm;

synchronized class Hist1 : Item 
{
	override string getType()   {
		return "Hist1";
	}
	override double getLeft()	{
		return _left;
	}
	override double getRight()	{
		return _right;
	}
	override double getBottom()	{
		return _bottom;
	}
	override double getTop()	{
		return _top;
	}
	override bool autoScaleX() {
		return _autoscale_x;
	}
	override bool autoScaleY()
	{
		return _autoscale_y;
	}
	override void draw(ref Scoped!Context cr, ViewBox box) {
		double bin_width = getBinWidth();
		double xhist = getLeft();
		double x = box.transform_box2canvas_x(xhist);
		double y = box.transform_box2canvas_y(0);

		// draw the start (the non repetetive stuff)
		cr.moveTo(x,y);
		y = box.transform_box2canvas_y(_bin_data[0]);
		cr.lineTo(x,y);
		xhist += bin_width;
		x = box.transform_box2canvas_x(xhist);
		cr.lineTo(x,y);

		// draw the repetitive stuff
		foreach(bin; _bin_data[1..$]) {
			y = box.transform_box2canvas_y(bin);
			cr.lineTo(x,y);
			xhist += bin_width;
			x = box.transform_box2canvas_x(xhist);
			cr.lineTo(x,y);
		}

		// draw the end of the line
		y = box.transform_box2canvas_y(0);
		cr.lineTo(x,y);
	}


	this(double[] bin_data, double left, double right)
	{
		_left = left;
		_right = right;
		_bin_data = cast(shared double[])bin_data.dup;
		if (_bin_data.length > 0) {
			_top    = maxElement(_bin_data);
			_bottom = minElement(_bin_data);
		} else {
			_top    =  1;
			_bottom = -1;
		}

	}

	double getBinWidth()
	{
		if (_bin_data.length == 0) {
			return 0;
		}
		return (_right - _left) / _bin_data.length;
	}


private:
	shared double[] _bin_data;
	shared double _left, _right;
	shared double _bottom, _top;
	shared bool _autoscale_y = false;
	shared bool _autoscale_x = false;
}