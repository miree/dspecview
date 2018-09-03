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

	this(string filename) {
		if (attrIsFile(getAttributes(filename))) {
			_filename = filename;
		} else {
			throw new Exception("not a valid file: " ~ filename);
		}
	}

	override immutable(Hist1Visualizer) createVisualizer() 
	{
		if (need_to_reload()) { // need to reload from file
			// try to read the data from file 
			try {
				auto hist = read_file(_filename);
				// In case we have an old referenced: release it. 	
	            // If nobody else holds a reference to this object the GC will take care
				_visualizer.length = 0; 
				// create a Visualizer for the loaded data
				_visualizer ~= new immutable(Hist1Visualizer)(hist.data, hist.left, hist.right);
			} catch (Exception e) {
				import std.stdio;
				writeln("unable to open file\r");
				// return a default visualizer
				return new immutable(Hist1Visualizer)();
			}
		}
		assert(_visualizer.length == 1); // at this point we should always have exactly one object in the array
		return _visualizer[0];
	}

private: // some private functions
	bool need_to_reload() {
		bool need_update = false;
		// test different conditions that make reload necessary
		SysTime time_last_file_modification = timeLastModified(cast(string)_filename);
		SysTime time_of_last_update = _time_of_last_update;
		if (time_of_last_update == SysTime.init ) need_update = true;
		if (_visualizer.length == 0) need_update = true;
		if (time_of_last_update < time_last_file_modification) need_update = true;

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
			writeln("opening file ", _filename, "\r");
			file = File(_filename,"r");
		} catch (Exception e) {
			if (!_filename.startsWith('/')) {
				_filename = "/" ~ _filename;
			}
			writeln("opening file ", _filename, "\r");
			file = File(_filename,"r");
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
					writeln("left = ", hist_left, " right = ", hist_right, "\r");
				} catch (Exception e) {
					writeln("Exception caught\r");
				}
			}
			if (!line.startsWith("#") && line.length > 0) {
				foreach(number; split(line.dup(), " ")) {
					if (number.length > 0)
						bin_data ~= std.conv.to!double(number);
				}
			}
		}
		file.close();
		return HistData(bin_data, hist_left, hist_right);
	}

private: // private state
	// make this an array to ba able discard the 
	// reference by assigning length = 0;
	immutable(Hist1Visualizer)[] _visualizer;
	string _filename;
	SysTime _time_of_last_update;
}


//////////////////////////////////////////////////
// Visualizer for 1D Histograms
immutable class Hist1Visualizer : Visualizer 
{
public:
	this() {
		_bin_data = null;
		_left = _right = double.init;
		_mipmap_data = null;
	}
	this(double[] data, double left, double right)
	{
		_bin_data = data.idup;
		_left     = left;
		_right    = right;
		_mipmap_data = make_mipmap_data();
	}

	override void print(int context) immutable 
	{
		import std.stdio;
		writeln("length of _bin_data: ", _bin_data.length);
		writeln("mipmap levels: ", _mipmap_data.length);
		foreach(idx, mipmap; _mipmap_data) {
			writeln("level(", idx, "): ", mipmap.length);
		}
	}

	import cairo.Context, cairo.Surface;
	import view;

	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz) immutable
	{
		
		
	}

private:

	/////////////////////////////////////////////////////////
	// calculate mipmap data from _bin_data
	// has to be pure to be allowed to return immutable
	immutable(minmax[][]) make_mipmap_data() pure 
	{
		if (_bin_data is null) {
			return null;
		}
		import std.algorithm, std.stdio;
		auto mipmap_data = new minmax[][0];
		for (int idx = 0;; ++idx) {
			if (idx == 0) {
				mipmap_data ~= new minmax[_bin_data.length-1];
				foreach(n, ref mip; mipmap_data[$-1]) {
					mip.min = min(_bin_data[n],_bin_data[n+1]);
					mip.max = max(_bin_data[n],_bin_data[n+1]);
				}
			} else {
				auto parent_len = mipmap_data[idx-1].length;
				if (parent_len == 1) {
					break;
				}
				mipmap_data ~= new minmax[(mipmap_data[idx-1].length+1) / 2];
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

	double[] _bin_data;
	double _left, _right;

	// mipmap data // TODO implement
	struct minmax {double min; double max;} ;
	minmax[][] _mipmap_data;
}

