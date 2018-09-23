import session;

//////////////////////////////////////////////////
// Visualizer for 1D Histograms
immutable class Hist1Visualizer : BaseVisualizer 
{
public:
	this() {
		super(0);
		_bin_data = null;
		_left = _right = double.init;
		_mipmap_data = null;
	}
	this(int colorIdx, double[] data, double left, double right)
	{
		super(colorIdx);
		_bin_data = data.idup;
		_left     = left;
		_right    = right;
		_mipmap_data = make_mipmap_data();
	}

	override ulong getDim() immutable
	{
		return 1;
	}

	override bool needsColorKey() immutable
	{
		return false;
	}

	import cairo.Context, cairo.Surface;
	import view;

	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz, ItemMouseAction mouse_action) immutable
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

	override bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable
	{
		import std.stdio;
		import logscale;
		left  = log_x_value_of(_left,  logx, getBinWidth()/2.0); // set the default_zero to half the bin size
		right = log_x_value_of(_right, logx, getBinWidth()/2.0);
		if (left is left.init || right is right.init) {
			return false;
		}
		return true;
	}

	override bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable
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
	double[] _bin_data;
	double _left, _right;

	// mipmap data // TODO implement
	struct MinMax {double min; double max;} ;
	MinMax[][] _mipmap_data;
}

