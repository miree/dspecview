import session;

//////////////////////////////////////////////////
// A histogram that is read from file and updated
// if the file has changed since last update
class FileHist1 : Item 
{
public:
	import std.datetime : abs, DateTime, hnsecs, SysTime;
	import std.datetime : Clock, seconds;		
	import std.file;

	this(string filename, int colorIdx) {
		if (attrIsFile(getAttributes(filename))) {
			_filename = filename;
			_colorIdx = colorIdx;
		} else {
			throw new Exception("not a valid file: " ~ filename);
		}
	}

	override string getTypeString() {
		if (_filename is null || _filename.length == 0) {
			return "unknown";
		}
		return "File Hist 1D";
	}

	override int getColorIdx() {
		return _colorIdx;
	}

	override immutable(Hist1Visualizer) createVisualizer() 
	{
		if (need_to_reload()) { // need to reload from file
			import std.stdio;
			//writeln("Hist1: need to reload from file: ", _filename, "\r");
			// try to read the data from file 
			try {
				auto hist = read_file(_filename);
				// In case we have an old referenced: release it. 	
	            // If nobody else holds a reference to this object the GC will take care
				_visualizer.length = 0; 
				// create a Visualizer for the loaded data
				_visualizer ~= new immutable(Hist1Visualizer)(_filename, _colorIdx, hist.data, hist.left, hist.right);
				if (_visualizer[0]._bin_data is null) {
					import std.stdio;
					writeln("visualizer was created with _bin_data is null\r");
				}
			} catch (Exception e) {
				import std.stdio;
				writeln("unable to open file\r");
				_filename = null;
				// return a default visualizer
			}
		}
		import std.stdio;
		//writeln("_visualizer.length = ", _visualizer.length, "\r");
		if (_visualizer.length < 1) { // no visualizer created yet
			_visualizer ~= null;//new immutable(Hist1Visualizer)();
		}
		return _visualizer[0];
	}

private: // some private functions
	bool need_to_reload() {
		bool need_update = false;
		import std.stdio;
		//writeln("need_update=", need_update,"\r");
		// test different conditions that make reload necessary
		SysTime time_last_file_modification = timeLastModified(cast(string)_filename);
		SysTime time_of_last_update = _time_of_last_update;
		if (time_of_last_update == SysTime.init ) need_update = true;
		//writeln("need_update=", need_update,"\r");
		if (_visualizer.length == 0) need_update = true;
		//writeln("need_update=", need_update,"\r");
		if (time_of_last_update < time_last_file_modification) need_update = true;
		//writeln("need_update=", need_update,"\r");
		_time_of_last_update = time_last_file_modification;

		return need_update;
	}

	struct HistData {
		double[] data;
		double left, right;
	}

	// try to open file, if it doesn't work, try 
	// to add a  leading '/' and try to open again
	auto open_file(string filename) {
		import std.stdio, std.algorithm;
		File file;
		try {
			//writeln("opening file ", _filename, "\r");
			file = File(_filename,"r");
			//writeln("file open ", _filename, "\r");
			file.lock(LockType.read);
		} catch (Exception e) {
			if (!_filename.startsWith('/')) {
				_filename = "/" ~ _filename;
			}
			//writeln("exception ", e.msg, " ... opening file ", _filename, "\r");
			file = File(_filename,"r");
			file.lock(LockType.read);
		} 
		return file;
	}

	auto read_file(string filename) {
		import std.stdio, std.algorithm, std.array, std.conv;

		auto file = open_file(filename);
		// reading content from file
		double hist_left, hist_right;
		double[] bin_data;
		foreach(line; file.byLine)	{
			if (line.startsWith("#")) {
				import std.format;
				// read something like this
				//# 2 500 0 0 3 500 1 0 3
				int dim, nbins;
				string name;
				double left, binwidth;
				try {
					line.formattedRead("# %s %s %s %s %s", dim, nbins, name, left, binwidth);
					hist_left = left;
					hist_right = left+binwidth*nbins;
					//writeln("left = ", hist_left, " right = ", hist_right, "\r");
				} catch (Exception e) {
					//writeln("Exception caught\r");
				}
			}
			if (!line.startsWith("#") && line.length > 0) {
				foreach(number; split(line.dup(), " ")) {
					if (number.length > 0) {
						bin_data ~= std.conv.to!double(number);
					}
				}
			}
		}
		file.close();
		// if the file didn't contain left/right information
		if (hist_left is double.init || hist_right is double.init) {
			hist_left = 0;
			hist_right = bin_data.length;
		}
		//writeln("read file left=",hist_left,"   right=",hist_right,"\r");
		return HistData(bin_data, hist_left, hist_right);
	}

private: // private state
	// make this an array to ba able discard the 
	// reference by assigning length = 0;
	immutable(Hist1Visualizer)[] _visualizer;
	string _filename;
	SysTime _time_of_last_update;
	int _colorIdx;
}


//////////////////////////////////////////////////
// Visualizer for 1D Histograms
immutable class Hist1Visualizer : Visualizer 
{
public:
	this() {
		_itemname = null;
		_bin_data = null;
		_left = _right = double.init;
		_mipmap_data = null;
		_colorIdx = 0;
	}
	this(string itemname, int colorIdx, double[] data, double left, double right)
	{
		_itemname = itemname;
		_colorIdx = colorIdx;
		_bin_data = data.idup;
		_left     = left;
		_right    = right;
		import std.stdio;
		//writeln("make mipmap data\r");
		_mipmap_data = make_mipmap_data();
		//writeln("done generating mipmap data\r");
	}

	override string getItemName() immutable
	{
		return _itemname;
	}

	override ulong getDim() immutable
	{
		return 1;
	}
	override int getColorIdx() immutable
	{
		return _colorIdx;
	}

	override void print(int context) immutable 
	{
		//import std.stdio;
		//writeln("length of _bin_data: ", _bin_data.length);
		//writeln("mipmap levels: ", _mipmap_data.length);
		//foreach(idx, mipmap; _mipmap_data) {
		//	writeln("level(", idx, "): ", mipmap.length);
		//}
	}

	override bool needsColorKey() immutable
	{
		return false;
	}

	import cairo.Context, cairo.Surface;
	import view;

	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz) immutable
	{
		import primitives;
		//void drawHistogram(T)(ref Scoped!Context cr, ViewBox box, double min, double max, T[] bins, bool logy = true, bool logx = false)
		import std.stdio;
		//writeln("drawHistram(,,",_left,",",_right,")\r");
		if (_bin_data is null) {
			return;
		}
		try {
			auto pixel_width = box.get_pixel_width();
			auto bin_width = getBinWidth;
			if (bin_width > pixel_width || logx) { // there is no mipmap implementation for logx histogram drawing
				drawHistogram(cr,box, _left, _right, _bin_data, logy, logx);
			} else {
				int mipmap_idx = 0;
				for (;;) {
					bin_width *= 2;
					++mipmap_idx;
					if (_mipmap_data !is null) {
						if (mipmap_idx == _mipmap_data.length-1 || bin_width > pixel_width) {
							drawMipMapHistogram(cr,box, _left, _right, _mipmap_data[mipmap_idx-1], logy);
							break;
						}
					}
					else writeln("_mipmap_data is null\r");
				}
			}
		} catch(Exception e) {
			writeln ("there was an Exception: ", e.file, ":", e.line, " -> ", e.msg, "\r");
		}
	}

	double getBinWidth()
	{
		//assert(_bin_data !is null);
		return (_right - _left) / _bin_data.length;
	}

	bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable
	{
		import std.stdio;
		import logscale;
		left  = log_x_value_of(_left,  logx);
		right = log_x_value_of(_right, logx);
		if (left is left.init || right is right.init) {
			return false;
		}
		return true;
	}
	bool getZminZmaxInLeftRightBottomTop(out double mi, out double ma, 
	                                     double left, double right, double bottom, double top, 
	                                     bool logz, bool logy, bool logx) immutable
	{ return false; }

	bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable
	{
		import std.stdio;
		//writeln("getBottomTopInLeftRight ", left, " ", right, "\r");
		if (_bin_data is null) {
			//writeln("getBottomTopInLeftRight _bin_data is null\r");
			return false;
		}
		if (_bin_data.length == 0) {
			//writeln("return false\r");
			return false;
		}
		if (_left is _left.init || _right is _right.init) {
			return false;
		}


		import std.math, std.algorithm;
		if (logx) { // special treatment for logx case
			right = exp(right);
			left = exp(left);
		}

		// transform into bin numbers
		left  = (left-_left)/getBinWidth();
		right = (right-_left)/getBinWidth();


		if (left >= _bin_data.length || right <= 0) {
			//writeln("done false\r");
			//writeln("return false\r");
			return false;
		}

		double minimum, maximum;
		bool initialize = true;
		int leftbin = cast(int)(max(left,0));
		int rightbin = cast(int)(min(right,_bin_data.length));
		//assert (leftbin <= rightbin);
		if (leftbin > rightbin) {
			import std.stdio;
			writeln("unexpected leftbin,rightbin: ", leftbin, "," , rightbin, "\r");
			return false;
		}
		foreach(i ; leftbin..rightbin+1){
			if (i < 0) {
				continue;
			}
			if (i >= _bin_data.length) {
				break;
			}
			import logscale;
			//assert(i >= 0 && i < _bin_data.length);
			if (i < 0 || i >= _bin_data.length) {
				writeln("unexpected bin: ", i, "\r");
				return false;
			}
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
			//writeln("return true\r");
			return true;
		}
		//writeln("return false\r");
		return false;		
	}


private:

	/////////////////////////////////////////////////////////
	// calculate mipmap data from _bin_data
	// has to be pure to be allowed to return immutable
	immutable(MinMax[][]) make_mipmap_data() pure 
	{
		if (_bin_data is null) {
			return null;
		}
		import std.algorithm, std.stdio;
		auto mipmap_data = new MinMax[][0];
		for (int idx = 0;; ++idx) {
			if (idx == 0) {
				// special case for histograms with only 1 bin
				if (_bin_data.length == 1) {
					mipmap_data ~= new MinMax[1];
					mipmap_data[$-1][0].min = mipmap_data[$-1][0].max = _bin_data[0];
				} else {
					mipmap_data ~= new MinMax[_bin_data.length-1];
					foreach(n, ref mip; mipmap_data[$-1]) {
						mip.min = min(_bin_data[n],_bin_data[n+1]);
						mip.max = max(_bin_data[n],_bin_data[n+1]);
					}
				}
			} else {
				auto parent_len = mipmap_data[idx-1].length;
				if (parent_len == 1) {
					break;
				}
				mipmap_data ~= new MinMax[(mipmap_data[idx-1].length+1) / 2];
				foreach(n, ref mip; mipmap_data[$-1]) {
					auto n2 = n*2, n2_plus_1 = n2+1;
					if (n2_plus_1 >= mipmap_data[idx-1].length) {
						n2_plus_1 = n2;
					}
					mip.min = min(mipmap_data[idx-1][n2].min, mipmap_data[idx-1][n2_plus_1].min);
					mip.max = max(mipmap_data[idx-1][n2].max, mipmap_data[idx-1][n2_plus_1].max);
				}
			}
		}
		return mipmap_data;
	}

private: // state	
	string _itemname;

	int _colorIdx;

	double[] _bin_data;
	double _left, _right;

	// mipmap data // TODO implement
	struct MinMax {double min; double max;} ;
	MinMax[][] _mipmap_data;
}

