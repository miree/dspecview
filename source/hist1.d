import drawable;
import view;
import primitives;
import logscale;

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
		_bin_data = cast(shared(double[]))_source.getData();
		mipmap_data();
		if (_bin_data !is null) {
			_top    = maxElement(_bin_data);
			_bottom = minElement(_bin_data);
			_left   = 0;
			_right  = _bin_data.length;
		} else {
			_bottom = -1;
			_top    =  1;
			_left   = -1;
			_right  =  1;
		}
	}

	override bool getBottomTopInLeftRight(ref double bottom, ref double top, in double left, in double right, bool logy) {
		if (_bin_data is null) {
			refresh();
		}
		if (left >= getRight || right <= getLeft) {
			return false;
		}
		double bottom_safe = bottom;
		double top_safe    = top;

		double minimum, maximum;
		bool initialize = true;
		foreach(i ; cast(int)left..cast(int)right+1){
			if (i < 0) {
				continue;
			}
			if (i >= _bin_data.length) {
				break;
			}
			import std.algorithm;
			assert(i >= 0 && i < _bin_data.length);
			if (initialize) {
				minimum = log_y_value_of(_bin_data[i], logy);
				maximum = log_y_value_of(_bin_data[i], logy);
				initialize = false;
			}
			minimum = min(minimum, log_y_value_of(_bin_data[i], logy));
			maximum = max(maximum, log_y_value_of(_bin_data[i], logy));
		}
		//if (minimum < maximum) {
		//	double height = maximum - minimum;
			bottom = minimum;
			top    = maximum;
		//} else { 
		//	// minimum == maximum 
		//	// (or minumum > maximum which shouldn't happen at all)
		//	bottom = -10;
		//	top    =  10;
		//}
		return true;
	}

	override void draw(ref Scoped!Context cr, ViewBox box, bool logy) {
		//writeln("Hist1Visualizer.draw() called\r");
		if (_bin_data is null) {
			refresh();
		}
		//writeln("bins = ", _bin_data[0].length, "\r");

		//writeln("pixel width = ", box.get_pixel_width() , "\r");
		auto pixel_width = box.get_pixel_width();
		auto bin_width = 1;
		if (bin_width > pixel_width) {
			drawHistogram(cr,box, 0,_bin_data.length, _bin_data, logy);
		} else {
			int mipmap_idx = 0;
			for (;;) {
				bin_width *= 2;
				++mipmap_idx;
				if (mipmap_idx == _mipmap_data.length-1 || bin_width > pixel_width) {
					drawMipMapHistogram(cr,box, 0, _bin_data.length, _mipmap_data[mipmap_idx-1], logy);
					break;
				}
			}
		}
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
		this._bin_data = cast(shared double[])bin_data.dup;
		mipmap_data();
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
		if (_bin_data is null || _bin_data.length == 0) {
			return double.init;
		}
		return (_right - _left) / _bin_data.length;
	}


private:
	void mipmap_data() 
	{
		if (_bin_data is null) {
			return;
		}
		import std.algorithm;
		for (int idx = 0;; ++idx) {
			if (idx == 0) {
				_mipmap_data ~= new minmax[_bin_data.length-1];
				foreach(n, ref mip; _mipmap_data[$-1]) {
					mip.min = min(_bin_data[n],_bin_data[n+1]);
					mip.max = max(_bin_data[n],_bin_data[n+1]);
				}
			} else {
				auto parent_len = _mipmap_data[idx-1].length;
				if (parent_len == 1) {
					break;
				}
				_mipmap_data ~= new minmax[(_mipmap_data[idx-1].length+1) / 2];
				foreach(n, ref mip; _mipmap_data[$-1]) {
					auto n2 = n*2, n2_plus_1 = n2+1;
					if (n2_plus_1 >= _mipmap_data[idx-1].length) {
						n2_plus_1 = n2;
					}
					mip.min = min(_mipmap_data[idx-1][n2].min, _mipmap_data[idx-1][n2_plus_1].min);
					mip.max = max(_mipmap_data[idx-1][n2].max, _mipmap_data[idx-1][n2_plus_1].max);
				}
			}
		}

	}

	shared Hist1Datasource _source;
	shared double[] _bin_data;
	shared string _name;

	alias struct minmax {double min; double max;} ;
	shared minmax[][] _mipmap_data;
}