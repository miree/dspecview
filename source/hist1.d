import session, hist1visualizer;

interface Hist1Interface
{
public:
	ulong getBins();
	double getLeft();
	double getRight();
	void fill(double pos, double amount = 1);
	void setBinContent(ulong idx, double value);
	double getBinContent(ulong idx);
}

//////////////////////////////////////////////////
// Visualizer for 1D Histograms
class Hist1 : Item , Hist1Interface
{
public:
	this(int colorIdx, ulong bins, double left, double right) pure
	{
		_colorIdx = colorIdx;
		_left     = left;
		_right    = right;
		_visualizer = null;
		_bin_data = new double[bins];
		_bin_data[] = 0.0;

		// pos = _a + _b * bin
		// left = _a              \
		// right = _a + _b * bins  => right = left + _b * bins
		//                         => _b = (right - left)/bins
		_a = left;
		_b = (right - left)/bins;
	}

	immutable(Visualizer) createVisualizer()
	{
		if (_is_dirty) { // need to reload from file
			import std.stdio;
			writeln("Hist1: need to generate new visuzlizer: \r");
			// try to read the data from file 
			try {
				_visualizer.length = 0; 
				_visualizer ~= new immutable(Hist1Visualizer)(_colorIdx, _bin_data, _left, _right);
				_is_dirty = false;
			} catch (Exception e) {
				import std.stdio;
				writeln("unable to create visuzlizer for hist1\r");
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
		return "Hist 1D " ~ _bin_data.length.to!string 
						  ~ " bins [" 
						  ~ _left.to!string 
						  ~ ":" 
						  ~ _right.to!string 
						  ~ "]";
	}
	int getColorIdx() {
		return _colorIdx;
	}
	void setColorIdx(int idx) {
		_colorIdx = idx;
	}


// Methods for Hist1Interface
	ulong getBins() {
		return _bin_data.length;
	}
	double getLeft() {
		return _left;
	}
	double getRight() {
		return _right;
	}
	void fill(double pos, double amount = 1) {
		import std.math;
		import std.stdio;
		int bin = cast(int)floor((pos - _a)/_b);
		//writeln("bin = ", bin, "\r");
		if (bin >= 0 && bin < _bin_data.length) {
			_bin_data[bin] += amount;
			_is_dirty = true;
		}
	}
	void setBinContent(ulong idx, double value) {
		_bin_data[idx] = value;
		_is_dirty = true;
	}
	double getBinContent(ulong idx) {
		return _bin_data[idx];
	}

private:
	// make this an array to be able discard the 
	// reference by assigning length = 0;
	immutable(Visualizer)[] _visualizer;

	int      _colorIdx;
	double[] _bin_data;
	double   _left;
	double   _right;
	bool     _is_dirty = true;

	double _a, _b; // pos = _a + _b * bin
}


immutable class Hist1Factory : ItemFactory
{
	this(ulong bins, double left, double right, int colorIdx = -1) pure {
		_bins = bins;
		_left = left;
		_right = right;
		_colorIdx = colorIdx;
	}
	override Item getItem() pure {
		return new Hist1(_colorIdx, _bins, _left, _right);
	}
private:	
	ulong     _bins;
	double    _left;
	double    _right;
	int       _colorIdx;
}
