import drawable;
import view;
import primitives;

import cairo.Context;
import cairo.Surface;
import std.algorithm, std.stdio;

// this can be asked for data and can be 
// represented by a real dataset or just 
// a link to a file from which the data is
// read on request
synchronized interface Hist1Datasource
{
	double[] getData();
}

synchronized class Hist1Filesource : Hist1Datasource 
{
	this(string filename) 
	{
		writeln("Hist1Filesource created on filename: ", filename);
		_filename = filename;		
	}

	double[] getData()
	{
		import std.array, std.algorithm, std.stdio, std.conv;
		//writeln("opening file ", _filename);
		auto file = File(_filename);
		double[] result;
		try {
			foreach(line; file.byLine)	{
				foreach(number; split(line.dup(), " ")) {
					if (number.length > 0)
						result ~= to!double(number);
				}
			}
		} catch (Exception e) {
			writeln("there was an Exeption ");
		}

		//writeln(file.byLine().map!(a => to!double(a)).array);
		return result;
	}
private:
	string _filename;
}

synchronized class Hist1Visualizer : Drawable 
{
	override string getType()   {
		return "Hist1";
	}
	override string getInfo() {
		return "empty histogram";
	}

	// get fresh data from the underlying source
	override void refresh() 
	{
		//writeln("Hist1Visualizer.refresh called()");
		_bin_data.length = 0;
		_bin_data ~= cast(shared(double[]))_source.getData();
		mipmap_data();
		if (_bin_data[0].length > 0) {
			_top    = maxElement(_bin_data[0]);
			_bottom = minElement(_bin_data[0]);
			_left   = 0;
			_right  = _bin_data[0].length;
		} else {
			_bottom = -1;
			_top    =  1;
			_left   = -1;
			_right  =  1;
		}
	}

	override void getBottomTopInLeftRight(ref double bottom, ref double top, in double left, in double right) {
		if (_bin_data.length == 0) {
			refresh();
		}
		if (left >= getRight || right <= getLeft) {
			return;
		}
		double bottom_safe = bottom;
		double top_safe    = top;

		double minimum, maximum;
		bool initialize = true;
		foreach(i ; cast(int)left..cast(int)right){
			if (i < 0) {
				continue;
			}
			if (i >= _bin_data[0].length) {
				break;
			}
			import std.algorithm;
			assert(i >= 0 && i < _bin_data[0].length);
			if (initialize) {
				minimum = _bin_data[0][i];
				maximum = _bin_data[0][i];
				initialize = false;
			}
			minimum = min(minimum, _bin_data[0][i]);
			maximum = max(maximum, _bin_data[0][i]);
		}
		if (minimum < maximum) {
			double height = maximum - minimum;
			bottom = minimum - 0.1*height;
			top    = maximum + 0.1*height;
		} else {
			bottom = -10;
			top    =  10;
		}
	}

	override void draw(ref Scoped!Context cr, ViewBox box) {
		//writeln("Hist1Visualizer.draw() called\r");
		if (_bin_data.length == 0) {
			refresh();
		}
		//writeln("bins = ", _bin_data[0].length, "\r");

		drawHistogram(cr,box, 0,_bin_data[0].length, _bin_data[0]);
	}


	this(string name, shared Hist1Datasource source)
	{
		super(name);
		_source = cast(shared Hist1Datasource)source;
	}

	this(string name, double[] bin_data, double left, double right)
	{
		super(name);
		_left = left;
		_right = right;
		_bin_data.length = 0;
		_bin_data ~= cast(shared double[])bin_data.dup;
		mipmap_data();
		if (_bin_data[0].length > 0) {
			_top    = maxElement(_bin_data[0]);
			_bottom = minElement(_bin_data[0]);
		} else {
			_top    =  1;
			_bottom = -1;
		}
	}

	double getBinWidth()
	{
		if (_bin_data.length == 0 || _bin_data[0].length == 0) {
			return 0;
		}
		return (_right - _left) / _bin_data[0].length;
	}


private:
	void mipmap_data() 
	{
		if (_bin_data.length == 0) {
			return;
		}

	}

	shared Hist1Datasource _source;
	shared double[][] _bin_data;
	shared string _name;
}