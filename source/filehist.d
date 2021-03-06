import session, hist1visualizer, hist2visualizer;

//////////////////////////////////////////////////
// A histogram that is read from file and updated
// if the file has changed since last update
class FileHist : Item 
{
public:
	import std.datetime : abs, DateTime, hnsecs, SysTime;
	import std.datetime : Clock, seconds;		
	import std.file;

	this(string filename, int colorIdx) pure {
			_filename = filename;
			_colorIdx = colorIdx;
	}

	override string getTypeString() {
		switch (_dim) {
			case 1:  return "File Hist 1D"; 
			case 2:  return "File Hist 2D"; 
			default: return "unknown"; 
		}
	}

	override int getColorIdx() {
		return _colorIdx;
	}
	override void setColorIdx(int idx) {
		_colorIdx = idx;
	}

	override immutable(Visualizer) createVisualizer() 
	{
		if (need_to_reload()) { // need to reload from file
			import std.stdio;
			//writeln("Hist1: need to reload from file: ", _filename, "\r");
			// try to read the data from file 
			try {
				if (!attrIsFile(getAttributes(_filename))) {
					throw new Exception("not a valid file: " ~ _filename);
				}
				auto hist = read_file(_filename);
				// In case we have an old referenced: release it. 	
	            // If nobody else holds a reference to this object the GC will take care
				_visualizer.length = 0; 
				// create a Visualizer for the loaded data
				switch(_dim) {
					case 1:
						_visualizer ~= new immutable(Hist1Visualizer)(_colorIdx, hist.data, hist.left, hist.right);
						if (hist.data is null) {
							import std.stdio;
							//writeln("visualizer was created with _bin_data is null\r");
						}
					break;
					case 2: {
						_visualizer.length = 0; 
						// create a Visualizer for the loaded data
						_visualizer ~= new immutable(Hist2Visualizer)(_colorIdx, hist.data, 
																	 hist.bins_x, hist.bins_y, 
																	 hist.left, hist.right, hist.bottom, hist.top);
					}
					break;
					default:
				}
			} catch (Exception e) {
				import std.stdio;
				writeln("unable to open file\r");
				_filename = null;
				// return a default visualizer
			}
		}
		import std.stdio;
		if (_visualizer.length < 1) { // no visualizer created yet
			_visualizer ~= null;//new immutable(Hist1Visualizer)();
		}
		return _visualizer[0];
	}

	void notifyItemChanged(string itemname, Item item) {
		// nothing
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

	//struct Hist1Data {
	//	double[] data;
	//	double left, right;
	//}
	struct HistData {
		double[] data;
		double left, right;
		double bottom, top;
		ulong bins_x, bins_y;
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

		try {
			auto file = open_file(filename);
			// reading content from file
			double hist_left, hist_right, hist_bottom, hist_top;
			double[] bin_data;
			ulong max_width = 0;
			bool has_fairy_header_1d = false;
			bool has_fairy_header_2d = false;
			foreach(line; file.byLine)	{
				if (line.startsWith("#")) {
					import std.format;
					// read something like this
					//# 2 500 0 0 3 500 1 0 3
					int dim, nbins;
					string name;
					double left, binwidth;
					int nbinsx, nbinsy;
					string namex, namey;
					double bottom, binheight;
					if (!(has_fairy_header_1d || has_fairy_header_2d)) {
						try { // try to read 2d fairy histogram
							line.dup.formattedRead("# %s %s %s %s %s %s %s %s %s", dim, nbinsx, namex, left,   binwidth, 
								                                                    nbinsy, namey, bottom, binheight);
							hist_left = left;
							hist_right = left+binwidth*nbinsx;
							hist_bottom = bottom;
							hist_top    = bottom+binheight*nbinsy;
							if (hist_left !is double.init && hist_right !is double.init &&
								hist_bottom !is double.init && hist_top !is double.init) {
								has_fairy_header_2d = true;
								//writeln("read 2d fairy header");
							}
							//writeln("left = ", hist_left, " right = ", hist_right, "\r");
						} catch (Exception e) {
						//writeln("Exception caught\r");
						}
					}
					if (!(has_fairy_header_1d || has_fairy_header_2d)) {
						try { // try to read 1d fairy histogram
							line.dup.formattedRead("# %s %s %s %s %s", dim, nbins, name, left, binwidth);
							hist_left = left;
							hist_right = left+binwidth*nbins;
							if (hist_left !is double.init && hist_right !is double.init) {
								has_fairy_header_1d = true;
								//writeln("read 1d fairy header");
							}
							//writeln("left = ", hist_left, " right = ", hist_right, "\r");
						} catch (Exception e) {
							//writeln("Exception caught\r");
						}
					}
				}

				if (!line.startsWith("#") && line.length > 0) {
					ulong width = 0;
					foreach(number; split(line.dup(), " ")) {
						if (number.length > 0) {
							bin_data ~= std.conv.to!double(number);
							++width;
						}
					}
					max_width = max(max_width, width);
				}

				//if (!line.startsWith("#") && line.length > 0) {
				//	foreach(number; split(line.dup(), " ")) {
				//		if (number.length > 0) {
				//			bin_data ~= std.conv.to!double(number);
				//		}
				//	}
				//}
			}
			file.close();

			// some heuristics to find the correct way to interpret the data
			// is first column only increasing?
			//if (max_width == 2 && 
			//	(bin_data.length%2) == 0 ) { // sparse 1d histogram
			//	double min_gap;
			//	bool only_increasing = true;
			//	if (bin_data.length > 4)
			//	foreach(idx; 2..bin_data.length/2) {
			//		double gap = bin_data[idx]-bin_data[idx-2];
			//		if (gap <= 0) {
			//			only_increasing = false;
			//			break;
			//		}
			//		if (min_gap is min_gap.init || min_gap > gap) {
			//			min_gap = gap;
			//		}
			//	}
			//	if ()
			//}
			// did we read a 1d histogram?
			if (max_width == 1 || max_width == bin_data.length) {
				_dim = 1;
				if (!has_fairy_header_1d) {
					hist_left = 0;
					hist_right = bin_data.length;
				}
				return HistData(bin_data, hist_left, hist_right);
			} else if (bin_data.length % max_width == 0) {
				_dim = 2;
				ulong w = max_width;
				ulong h = bin_data.length / max_width;
				if (!has_fairy_header_2d) {
					hist_left = 0;
					hist_right = w;
					hist_bottom = 0;
					hist_top = h;
				}
				return HistData(bin_data, hist_left, hist_right, hist_bottom, hist_top, w, h);
			}
			_dim = 0;
			return HistData();
			//// if the file didn't contain left/right information
			//if (hist_left is double.init || hist_right is double.init) {
			//	hist_left = 0;
			//	hist_right = bin_data.length;
			//}
			////writeln("read file left=",hist_left,"   right=",hist_right,"\r");
			//_dim = 1;
			//return HistData(bin_data, hist_left, hist_right);
		} catch (Exception e) {
			writeln("Can not read file ", _filename, "\r");
			return HistData();
		}
	}


private: // private state
	// make this an array to be able discard the 
	// reference by assigning length = 0;
	immutable(Visualizer)[] _visualizer;
	string _filename;
	SysTime _time_of_last_update;
	int _colorIdx;
	int _dim = 0;
}

immutable class FileHistFactory : ItemFactory
{
	this(string filename, int colorIdx = -1) pure {
		_filename = filename;
		_colorIdx = colorIdx;
	}
	override Item getItem() pure {
		return new FileHist(_filename, _colorIdx);
	}
private:	
	string    _filename;
	int       _colorIdx;
}
