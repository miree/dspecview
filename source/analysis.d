import session, hist1visualizer;

interface AnalysisInterface
{
public:
	void start(long steps = -1);
	void stop();
	void step();
	void idle();
}

//////////////////////////////////////////////////
// Visualizer for 1D Histograms
class Analysis : Item , AnalysisInterface
{
public:
	this(int colorIdx, string filename) pure
	{
		_colorIdx = colorIdx;
		_filename = filename; // analysis configuration file
		_steps_left  = 0;

		h1 = new Hist1(1, 100, -20, 20);
		h2 = new Hist1(2, 100, -10, 10);
		h12 = new Hist2(3, 1000, 1000, -20, 20, -20, 20);
	}

	immutable(Visualizer) createVisualizer()
	{
		return null;
	}	
	string getTypeString() {
		import std.conv;
		return "Analysis " ~ (_steps_left != 0)?("running"):("stopped");
	}
	int getColorIdx() {
		return _colorIdx;
	}
	void setColorIdx(int idx) {
		_colorIdx = idx;
	}

	void start(long steps = -1) {

		import std.concurrency;
		import session;
		thisTid.send(MsgInsertItem("h1", cast(immutable(Item))h1));
		thisTid.send(MsgInsertItem("h2", cast(immutable(Item))h2));
		thisTid.send(MsgInsertItem("h12", cast(immutable(Item))h12));

		_steps_left = steps;
		step();
	}
	void stop() {
		_steps_left = 0;
	}

// Methods for AnalysisInterface
	void step() {
		if (_steps_left == 0) {
			return;
		}
		import std.stdio;
		// do whatever has to be done ...
	
			//writeln("analysis step ", _steps_left, "\r");

			// toy analysis: create two random values and put them 
			//               into histograms
			import std.random;
			static auto rnd = Random(42);
			double value1 = uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd);
			double value2 = value1
						+   uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd)
				        +   uniform(-1.,1.,rnd);


			h1.fill(value1);
			h2.fill(value2);
			h12.fill(value1, value2);

		// check if we should continue
		if (_steps_left > 0) {
			--_steps_left;
		}
		import session;
		if (_steps_left > 0 || _steps_left == -1) {
			import std.concurrency;
			thisTid.send(MsgAnalysisStep(cast(immutable(Analysis))this, false));
		}
	}

	void idle() {
	}

private:
	// make this an array to be able discard the 
	// reference by assigning length = 0;
	immutable(Visualizer)[] _visualizer;

	int      _colorIdx;
	string   _filename;
	long     _steps_left; // number of steps to be done
	                   // -1 for unlimited number of steps

	import hist1;
	import hist2;
	Hist1 h1 = null;
	Hist1 h2 = null;
	Hist2 h12 = null;

}


immutable class AnalysisFactory : ItemFactory
{
	this(string filename, int colorIdx = -1) pure {
		_filename = filename;
		_colorIdx = colorIdx;
	}
	override Item getItem() pure {
		return new Analysis(_colorIdx, _filename);
	}
private:
	string    _filename;
	int       _colorIdx;
}
