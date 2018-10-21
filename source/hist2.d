import session;


interface Hist2Interface
{
public:
	ulong  getBinsX();
	ulong  getBinsY();
	double getLeft();
	double getRight();
	double getBottom();
	double getTop();
	void   fill(double x, double y, double amount = 1);
	void   setBinContent(ulong x, ulong y, double value);
	double getBinContent(ulong x, ulong y);
}

//////////////////////////////////////////////////
// Visualizer for 2D Histograms
class Hist2 : Item, Hist2Interface 
{
public:
	this(int colorIdx, ulong bins_x, ulong bins_y, 
		 double left, double right,
		 double bottom, double top) pure {
		_left        = left;
		_right       = right;
		_bottom      = bottom;
		_top         = top;
		_bins_x      = bins_x;
		_bins_y      = bins_y;
		_bin_data    = new double[bins_x* bins_y];
		_bin_data[]  = 0.0;
		_is_dirty    = true;

		_a_x = left;
		_b_x = (right - left)/bins_x;

		_a_y = bottom;
		_b_y = (top - bottom)/bins_y;
	}


	immutable(Visualizer) createVisualizer()
	{
		import std.stdio;
		import hist2visualizer;
		if (_is_dirty) { // need to reload from file
			//writeln("Hist2: need to generate new visuzlizer: \r");
			// try to read the data from file 
			try {
				_visualizer.length = 0; 
				_visualizer ~= new immutable(Hist2Visualizer)(_colorIdx, _bin_data,
															  _bins_x, _bins_y, 
															  _left, _right, _bottom, _top);
				_is_dirty = false;
			} catch (Exception e) {
				import std.stdio;
				writeln("cannot create visuzlizer for hist2\r");
			}
		}
		import std.stdio;
		if (_visualizer.length < 1) { // no visualizer created yet
			_visualizer ~= null;//new immutable(Hist1Visualizer)();
		}
		return _visualizer[0];
	}	

	string getTypeString() {
		import std.conv;
		return "Hist 2D " ~ _bins_x.to!string 
						  ~ "x" 
						  ~ _bins_y.to!string 
						  ~ " bins [" 
						  ~ _left.to!string 
						  ~ ":" 
						  ~ _right.to!string 
						  ~ "]["
						  ~ _bottom.to!string 
						  ~ ":" 
						  ~ _top.to!string 
						  ~ "]";
	}
	int getColorIdx() {
		return _colorIdx;
	}
	void setColorIdx(int idx) {
		_colorIdx = idx;
	}


// Methods for Hist1Interface
	ulong getBinsX() {
		return _bins_x;
	}
	ulong getBinsY() {
		return _bins_y;
	}
	double getLeft() {
		return _left;
	}
	double getRight() {
		return _right;
	}
	double getBottom() {
		return _bottom;
	}
	double getTop() {
		return _top;
	}
	void fill(double x, double y, double amount = 1) {
		import std.math;
		import std.stdio;
		int binx = cast(int)floor((x - _a_x)/_b_x);
		int biny = cast(int)floor((y - _a_y)/_b_y);
		//writeln("bin = ", bin, "\r");
		if (binx >= 0 && binx < _bins_x &&
			biny >= 0 && biny < _bins_y) {
			_bin_data[binx+biny*_bins_x] += amount;
			_is_dirty = true;
		}
	}
	void setBinContent(ulong x, ulong y, double value) {
		_bin_data[x+_bins_x*y] = value;
		_is_dirty = true;
	}
	double getBinContent(ulong x, ulong y) {
		return _bin_data[x+_bins_x*y];
	}

private:
	// make this an array to be able discard the 
	// reference by assigning length = 0;
	immutable(Visualizer)[] _visualizer;

	int      _colorIdx;
	double[] _bin_data;
	ulong    _bins_x;
	ulong    _bins_y;
	double   _left;
	double   _right;
	double   _bottom;
	double   _top;
	bool     _is_dirty = true;

	double _a_x, _b_x; // posx = _a_x + _b_x * binx
	double _a_y, _b_y; // posy = _a_y + _b_y * biny
}


immutable class Hist2Factory : ItemFactory
{
	this(ulong bins_x, ulong bins_y, 
		double left, double right, 
		double bottom, double top, 
		int colorIdx = -1) pure {
		_bins_x   = bins_x;
		_bins_y   = bins_y;
		_left     = left;
		_right    = right;
		_bottom   = bottom;
		_top      = top;
		_colorIdx = colorIdx;
	}
	override Item getItem() pure {
		return new Hist2(_colorIdx, _bins_x, _bins_y,
						 _left, _right, _bottom, _top);
	}
private:	
	ulong     _bins_x;
	ulong     _bins_y;
	double    _left;
	double    _right;
	double    _bottom;
	double    _top;
	int       _colorIdx;
}
