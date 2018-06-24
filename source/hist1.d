import drawable;
import view;

import cairo.Context;
import cairo.Surface;
import std.algorithm;

// this can be asked for data and can be 
// represented by a real dataset or just 
// a link to a file from which the data is
// read on request
synchronized interface Hist1Datasource
{
	double[] getData();
	double   getLeft();
	double   getRight();
}

synchronized class Hist1Visualizer : Drawable 
{
	//override string getType()   {
	//	return "Hist1";
	//}
	//override string getInfo() {
	//	return "empty histogram";
	//}

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


	this(Hist1Datasource source)
	{

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
	shared Hist1Datasource _source;
	shared double[] _bin_data;
}