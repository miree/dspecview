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
		_steps_left = steps;
		step();
	}
	void stop() {
		_steps_left = 0;
	}

// Methods for AnalysisInterface
	void step() {
		if (_steps_left > 0) {
			--_steps_left;
		}
		if (_steps_left == 0) {
			return;
		}
		import std.concurrency;
		import std.stdio;
		// do whatever has to be done ...
			writeln("analysis step ", _steps_left, "\r");

			// load event data
			// process event
			// create histograms
			// fill histograms

		// check if we should continue
		import session;
		if (_steps_left > 0 || _steps_left == -1) {
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
	long      _steps_left; // number of steps to be done
	                   // -1 for unlimited number of steps
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
