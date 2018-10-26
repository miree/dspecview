import session, hist1visualizer;

interface SoundScopeInterface
{
public:
	void start(long steps = -1);
	void stop();
	void step();
	void idle();
}

//////////////////////////////////////////////////
// Visualizer for 1D Histograms
class SoundScope : Item , SoundScopeInterface
{
public:
	this(int colorIdx, string filename) pure
	{
		_colorIdx = colorIdx;
		_filename = filename; // SoundScope configuration file
		_steps_left  = 0;
		_step_counter = 0; // counts all steps since creation of object

		int leftcoloridx = 4;
		int rightcoloridx = 5;

		_channel_left  = new Hist1(leftcoloridx,  tracelen, 0, tracelen);
		_channel_right = new Hist1(rightcoloridx, tracelen, 0, tracelen);

		_left_trigger_level  = new Number(0, 0, false, leftcoloridx, Direction.y);
		_right_trigger_level = new Number(0, 0, false, rightcoloridx, Direction.y);

		//_left_top = new Number( 10000, 0, false, leftcoloridx, Direction.y);
		//_left_bot = new Number(-10000, 0, false, leftcoloridx, Direction.y);

		//_right_top = new Number( 10000, 0, false, rightcoloridx, Direction.y);
		//_right_bot = new Number(-10000, 0, false, rightcoloridx, Direction.y);

		import std.stdio;
	}
	~this(){

	}

	immutable(Visualizer) createVisualizer()
	{
		return null;
	}	
	string getTypeString() {
		import std.conv;
		string typestring = "SoundScope " ~ _step_counter.to!string ~ " steps - ";
		return typestring ~ ((_steps_left == 0)?"stopped":"running");
	}
	int getColorIdx() {
		return _colorIdx;
	}
	void setColorIdx(int idx) {
		_colorIdx = idx;
	}

	void start(long steps = -1) {

		import std.stdio;

		// open pcm hardware
		rc = snd_pcm_open(&handle, "default", snd_pcm_stream_t.CAPTURE, 0);
		if (rc < 0) 
		{
			writeln("unable to open pcm device: ", rc);
			return;
		}

		// get set of default hardware parameters
		snd_pcm_hw_params_malloc(&params); 

		snd_pcm_hw_params_any(handle, params);
		if (snd_pcm_hw_params_set_access(handle, params, snd_pcm_access_t.RW_INTERLEAVED)) writeln("error: snd_pcm_hw_params_set_access");
		if (snd_pcm_hw_params_set_format(handle, params, snd_pcm_format_t.S32_LE)) writeln("error: snd_pcm_hw_params_set_format");
		if (snd_pcm_hw_params_set_channels(handle, params, 2)) writeln("error: snd_pcm_hw_params_set_channels");
		if (snd_pcm_hw_params_set_rate(handle, params, rate, 0)) writeln("error: snd_pcm_hw_params_set_rate");
		if (snd_pcm_hw_params_set_period_size(handle, params, period_length, 0)) writeln("error: snd_pcm_hw_params_set_period_size");

		// write the parameters to the driver 
		rc = snd_pcm_hw_params(handle, params);
		if (rc < 0) 
		{
			writeln("unable to set hw parameters: ", rc);
			return;
		}
		writeln("ready to record\r");


		writeln("SoundScope started\r");
		if (_steps_left == 0) {
			import std.concurrency;
			import session;
			thisTid.send(MsgInsertItem("left/signal", cast(immutable(Item))_channel_left));
			thisTid.send(MsgInsertItem("left/triggerlevel", cast(immutable(Item))_left_trigger_level));

			//thisTid.send(MsgInsertItem("left/top", cast(immutable(Item))_left_top));
			//thisTid.send(MsgInsertItem("left/bot", cast(immutable(Item))_left_bot));


			thisTid.send(MsgInsertItem("right/signal", cast(immutable(Item))_channel_right));
			thisTid.send(MsgInsertItem("right/triggerlevel", cast(immutable(Item))_right_trigger_level));
			//thisTid.send(MsgInsertItem("right/top", cast(immutable(Item))_right_top));
			//thisTid.send(MsgInsertItem("right/bot", cast(immutable(Item))_right_bot));

			_steps_left = steps;
			step();
		} else {
			import std.stdio;
			writeln("SoundScope already running\r");
		}


	}
	void stop() {
		_steps_left = 0;
	}

// Methods for SoundScopeInterface
	void step() {
		if (_steps_left == 0) {
			import session;
			import std.concurrency;
			thisTid.send(MsgRequestRefreshItemList());
			//snd_pcm_hw_free(handle);
			//snd_pcm_hw_params_free(params);
			return;
		}
		import std.stdio;
		// do whatever has to be done ...
	

		long sr = snd_pcm_readi(handle, cast(char*)(buffer), period_length);
		if (sr < 0)
		{
			sr = snd_pcm_recover(handle, rc, 0);
			if (sr < 0)
			{
				writeln("cannot recover\r");
				return;
			}
		}

		for (int p = 0; p < period_length; ++p)
		{
			int leftvalue = buffer[2*p]>>16;
			if (leftvalue > _left_trigger_level.getValue() && lefttrace[_left_bin_counter] <= _left_trigger_level.getValue()) {
				lefttrigger = true;
			}
			lefttrace[_left_bin_counter]  = leftvalue;

			if (lefttrigger) {
				++_left_bin_counter;
				if (_left_bin_counter == tracelen) {
					_left_bin_counter = 0;
					lefttrigger = false;
					for (long i = 0; i < tracelen; ++i) {
						_channel_left.setBinContent(i, lefttrace[i]);
					}
				}
			}


			int rightvalue = buffer[2*p+1]>>16;
			if (rightvalue > _right_trigger_level.getValue() && righttrace[_right_bin_counter] <= _right_trigger_level.getValue()) {
				righttrigger = true;
			}
			righttrace[_right_bin_counter] = rightvalue;

			if (righttrigger) {
				++_right_bin_counter;
				if (_right_bin_counter == tracelen) {
					_right_bin_counter = 0;
					righttrigger = false;
					for (long i = 0; i < tracelen; ++i) {
						_channel_right.setBinContent(i, righttrace[i]);
					}
				}
			}

			//writeln(sum_l, " ", sum_r, "\r");
		}

		// check if we should continue
		++ _step_counter;

		if (_steps_left > 0) {
			--_steps_left;
			if (_steps_left == 0) {
				import gui;
				import std.concurrency;
				thisTid.send(MsgRequestRefreshItemList());
				//snd_pcm_hw_free(handle);
				//snd_pcm_hw_params_free(params);
			}
		}
		import session;
		if (_steps_left > 0 || _steps_left == -1) {
			import std.concurrency;
			thisTid.send(MsgSoundScopeStep(cast(immutable(SoundScope))this, false));
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

	long     _step_counter;

	import hist1;
	Hist1 _channel_left  = null;
	Hist1 _channel_right = null;
	import number;
	Number _left_trigger_level;
	Number _right_trigger_level;
	//Number _left_top,  _left_bot;
	//Number _right_top, _right_bot;


	// alsa stuff
	import deimos.alsa.pcm;
	immutable uint                  period_length = 32;     // 32 frames in one period
	immutable uint                  rate          = 192000; // as fast as we can
	immutable uint                  num_channels  = 2;      // stereo
	immutable uint                  tracelen      = 512;    // number of bins of the histograms showing the trace
	int[tracelen]                   lefttrace;
	bool                            lefttrigger;
	long _left_bin_counter = 0;
	int[tracelen]                   righttrace;
	bool                            righttrigger;
	long _right_bin_counter = 0;
	snd_pcm_hw_params_t             *params;
	snd_pcm_t                       *handle;                // a handle to pcm device
	int[num_channels*period_length] buffer;                 // buffer for the sound data
	int rc;                                                 // pcm function return code



}


immutable class SoundScopeFactory : ItemFactory
{
	this(string filename, int colorIdx = -1) pure {
		_filename = filename;
		_colorIdx = colorIdx;
	}
	override Item getItem() pure {
		return new SoundScope(_colorIdx, _filename);
	}
private:
	string    _filename;
	int       _colorIdx;
}
