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
	//bool dirty(); // returns true if the data was changed since last call of getData
	shared(double[]) getData(out double hist_left, out double hist_right);
}

synchronized class Hist1Memory : Hist1Datasource
{
	this(int bins, double left = double.init, double right = double.init)
	{
		_bin_data = new double[bins];
		_bin_data[] = 0;
		if (_bin_data.length > 1) { _bin_data[0] = 0.01; }
		if (_bin_data.length > 2) { _bin_data[1] = 0.1; }
		if (_bin_data.length > 3) { _bin_data[2] = 1; }
		if (left is double.init || right is double.init) {
			_left = 0;
			_right = bins;
		} else {
			_left = left;
			_right = right;				
		}
	}

	override shared(double[]) getData(out double hist_left, out double hist_right)
	{
		hist_right = _right;
		hist_left  = _left;
		return _bin_data;
	}
private:

	shared double _left, _right;
	shared double[] _bin_data;
}

synchronized class Hist1Filesource : Hist1Datasource 
{
	import std.datetime : abs, DateTime, hnsecs, SysTime;
	import std.datetime : Clock, seconds;

	this(string filename) 
	{
		writeln("Hist1Filesource created on filename: ", filename);
		_filename = filename;		
	}


	override shared(double[]) getData(out double hist_left, out double hist_right)
	{
		import std.array, std.algorithm, std.stdio, std.conv;
		import std.file;
		import std.datetime : abs, DateTime, hnsecs, SysTime;
		import std.datetime : Clock, seconds;		

		writeln("Hist1Filesource.getData() called\r");

		File file;
		SysTime time_last_file_modification = timeLastModified(cast(string)_filename);
		bool need_update = false;
		SysTime time_of_last_update = _time_of_last_update;
		if (time_of_last_update == SysTime.init ) need_update = true;
		if (_bin_data is null) need_update = true;
		if (time_of_last_update < time_last_file_modification) need_update = true;
		if (!need_update) {
			hist_left   = _left  ;
			hist_right  = _right ;
			return _bin_data;
		}
		try {
			//writeln("opening file ", _filename);
			file = File(_filename,"r");
		} catch (Exception e) {
			try {
				if (!_filename.startsWith('/')) {
					_filename = "/" ~ _filename;
				}
				writeln("opening file ", _filename);
				file = File(_filename,"r");
			} catch (Exception e) {
				writeln("unable to open file ", _filename);
				return null;
			}
		} 
		writeln("update hist\r");

		while(!file.tryLock(LockType.read)) {
			writeln("lock not successfull\r");
		    int waitTime = 100;
		   	writeln("waiting");
		   	import core.thread;
	    	Thread.sleep(waitTime.msecs);
		}
		writeln("lock successfull\r");
		_bin_data.length = 0;
		try {
			foreach(line; file.byLine)	{
				if (line.startsWith("#")) {
					import std.format;
					//# 2 500 0 0 3 500 1 0 3
					int dim, nbins;
					string name;
					double left, binwidth;
					try {
						line.formattedRead("# %s %s %s %s %s", dim, nbins, name, left, binwidth);
						hist_left = left;
						hist_right = left+binwidth*nbins;
						writeln("left = ", hist_left, " right = ", hist_right, "\r");
					} catch (Exception e) {
						writeln("Exception caught\r");
					}

				}
				if (!line.startsWith("#") && line.length > 0) {
					foreach(number; split(line.dup(), " ")) {
						if (number.length > 0)
							_bin_data ~= to!double(number);
					}
				}
			}
			writeln("no Exception\r");
		} catch (Exception e) {
			writeln("there was an Exeption ");
			writeln("returning null\r");
			return null;
		}
		file.close();
		writeln("file closed\r");


		if (hist_left is double.init) hist_left = 0;
		if (hist_right is double.init) hist_right = _bin_data.length;
		//writeln(file.byLine().map!(a => to!double(a)).array);
		writeln("saving update time\r");
		SysTime *time_of_last_update_ptr = cast(SysTime*)(&_time_of_last_update);
		*time_of_last_update_ptr = time_last_file_modification;
		_left   = hist_left;
		_right  = hist_right;
		writeln("returning\r");
		return _bin_data;	
	}
private:
	string _filename;
	shared double _left, _right;
	shared(double[]) _bin_data;
	shared(SysTime) _time_of_last_update;
}

synchronized class Hist1Visualizer : Drawable 
{
	override string getType()   {
		return "Hist1";
	}
	override string getInfo() {
		return "empty histogram";
	}

	override int getDim() {
		return 1;
	}


	// get fresh data from the underlying source
	override void refresh() 
	{
		writeln("Hist1Visualizer.refresh called()");
		double left, right;
		auto _old_data = _bin_data;
		_bin_data = cast(shared(double[]))_source.getData(left, right);
		if (_bin_data !is null) {
			if (_old_data != _bin_data) {
				mipmap_data();
			}
			_top    = maxElement(_bin_data);
			_bottom = minElement(_bin_data);
			_left   = left;
			_right  = right;
		} else {
			_bottom = -1;
			_top    =  1;
			_left   = -1;
			_right  =  1;
		}
	}

	override bool getBottomTopInLeftRight(ref double bottom, ref double top, double left, double right, bool logy, bool logx) {
		writeln("getBottomTopInLeftRight ", left, " ", right, "\r");
		if (_bin_data is null) {
			refresh();
			if (_bin_data is null) {
				return false;
			}
		}
		import std.math;
		if (logx) { // special treatment for logx case
			right = exp(right);
			left = exp(left);
		}

		if (_bin_data.length == 0) {
			return false;
		}
		// transform into bin numbers
		writeln("critical: getLeft=", getLeft(), "   getRight=",getRight(), 
			    "   getBinWidth=",getBinWidth(),"\r");
		left  = (left-getLeft())/getBinWidth();
		right = (right-getLeft())/getBinWidth();
		writeln("critical: getLeft=", getLeft(), "   getRight=",getRight(), 
			    "   getBinWidth=",getBinWidth(),"\r");

		if (left )

		writeln("getBottomTopInLeftRight ", left, " ", right, "\r");

		if (left >= _bin_data.length || right <= 0) {
			//writeln("done false\r");
			return false;
		}
		double bottom_safe = bottom;
		double top_safe    = top;

		double minimum, maximum;
		bool initialize = true;
		int leftbin = cast(int)(max(left,0));
		int rightbin = cast(int)(min(right,_bin_data.length));
		assert (leftbin <= rightbin);
		foreach(i ; leftbin..rightbin+1){
			if (i < 0) {
				continue;
			}
			if (i >= _bin_data.length) {
				break;
			}
			import std.algorithm;
			assert(i >= 0 && i < _bin_data.length);
			if ((logy && (_bin_data[i] > 0)) || !logy) {
				if (initialize) {
					minimum = log_y_value_of(_bin_data[i], logy);
					maximum = log_y_value_of(_bin_data[i], logy);
					initialize = false;
				}
				minimum = min(minimum, log_y_value_of(_bin_data[i], logy));
				maximum = max(maximum, log_y_value_of(_bin_data[i], logy));
			}
		}
		if (!initialize) {
			bottom = minimum;
			top    = maximum;
			return true;
		}
		return false;
	}

	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz) {
		writeln("Hist1Visualizer.draw() called\r");
		if (_bin_data is null) {
			refresh();
			if (_bin_data is null) {
				return;
			}
		}
		if (_bin_data !is null) {
			writeln("bins = ", _bin_data.length, "\r");
		} else {
			writeln("_bin_data is null\r");
		}

		writeln("pixel width = ", box.get_pixel_width() , "\r");
		auto pixel_width = box.get_pixel_width();
		auto bin_width = getBinWidth;
		if (bin_width > pixel_width || logx) { // there is no mipmap implementation for logx histogram drawing
			writeln("hist1 draw\r");
			drawHistogram(cr,box, getLeft, getRight, _bin_data, logy, logx);
		} else {
			writeln("hist1 draw mipmap\r");
			int mipmap_idx = 0;
			for (;;) {
				bin_width *= 2;
				++mipmap_idx;
				if (_mipmap_data !is null) {
					if (mipmap_idx == _mipmap_data.length-1 || bin_width > pixel_width) {
						drawMipMapHistogram(cr,box, getLeft, getRight, _mipmap_data[mipmap_idx-1], logy);
						break;
					}
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
		import std.algorithm, std.stdio;
		writeln("generate mipmap data\r");
		_mipmap_data.length = 0;
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
		writeln("done generating mipmap data\r");

	}

	shared Hist1Datasource _source;
	shared double[] _bin_data;
	shared string _name;

	alias struct minmax {double min; double max;} ;
	shared minmax[][] _mipmap_data;
}