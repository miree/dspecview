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
	this(string itemname, int colorIdx, string filename) pure
	{
		_itemname = itemname;
		_colorIdx = colorIdx;
		_filename = filename; // SoundScope configuration file
		_steps_left  = 0;
		_step_counter = 0; // counts all steps since creation of object

		int leftcoloridx = 0;
		int rightcoloridx = 5;

		_channel_left  = new Hist1(leftcoloridx,  tracelen, 1.0-tracelen/2, 1.0*tracelen-tracelen/2);
		_channel_right = new Hist1(rightcoloridx, tracelen, 1.0-tracelen/2, 1.0*tracelen-tracelen/2);

		_left_trigger_level  = new Number(5000, 0, false, leftcoloridx, Direction.y);
		_right_trigger_level = new Number(-5000, 0, false, rightcoloridx, Direction.y);

		_left_offset  = new Number(5000, 0, false, leftcoloridx+1, Direction.y);
		_right_offset = new Number(-5000, 0, false, rightcoloridx+1, Direction.y);

		_left_timezero  = new Number(0, 0, false, leftcoloridx, Direction.x);
		_right_timezero = new Number(0, 0, false, rightcoloridx, Direction.x);

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

	void notifyItemChanged(string itemname, Item item) {
		import std.stdio;
		//writeln("item ", itemname, " changed\r");
		Number number = cast(Number)item;
		if (number !is null) {
			if (itemname == _itemname ~ "/left/triggerlevel") {
				_left_trigger_level = number;
			}
			if (itemname == _itemname ~ "/left/offset") {
				_left_offset = number;
			}
			if (itemname == _itemname ~ "/left/timezero") {
				_left_timezero = number;
			}
			if (itemname == _itemname ~ "/right/triggerlevel") {
				_right_trigger_level = number;
			}
			if (itemname == _itemname ~ "/right/offset") {
				_right_offset = number;
			}
			if (itemname == _itemname ~ "/right/timezero") {
				_right_timezero = number;
			}
		}
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
			thisTid.send(MsgInsertItem(_itemname ~ "/left/signal", cast(immutable(Item))_channel_left));
			thisTid.send(MsgInsertItem(_itemname ~ "/left/triggerlevel", cast(immutable(Item))_left_trigger_level));
			thisTid.send(MsgInsertItem(_itemname ~ "/left/offset", cast(immutable(Item))_left_offset));
			thisTid.send(MsgInsertItem(_itemname ~ "/left/timezero", cast(immutable(Item))_left_timezero));
			thisTid.send(MsgNotifyMeOnItemChange(_itemname, _itemname ~ "/left/triggerlevel"));
			thisTid.send(MsgNotifyMeOnItemChange(_itemname, _itemname ~ "/left/timezero"));
			thisTid.send(MsgNotifyMeOnItemChange(_itemname, _itemname ~ "/left/offset"));

			//thisTid.send(MsgInsertItem("left/top", cast(immutable(Item))_left_top));
			//thisTid.send(MsgInsertItem("left/bot", cast(immutable(Item))_left_bot));


			thisTid.send(MsgInsertItem(_itemname ~ "/right/signal", cast(immutable(Item))_channel_right));
			thisTid.send(MsgInsertItem(_itemname ~ "/right/triggerlevel", cast(immutable(Item))_right_trigger_level));
			thisTid.send(MsgInsertItem(_itemname ~ "/right/offset", cast(immutable(Item))_right_offset));
			thisTid.send(MsgInsertItem(_itemname ~ "/right/timezero", cast(immutable(Item))_right_timezero));
			thisTid.send(MsgNotifyMeOnItemChange(_itemname, _itemname ~ "/right/triggerlevel"));
			thisTid.send(MsgNotifyMeOnItemChange(_itemname, _itemname ~ "/right/timezero"));
			thisTid.send(MsgNotifyMeOnItemChange(_itemname, _itemname ~ "/right/offset"));
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
			writeln("sr < 0\r");
			sr = snd_pcm_recover(handle, rc, 0);
			if (sr < 0)
			{
				writeln("cannot recover\r");
				return;
			}
		} else {
			for (int p = 0; p < period_length; ++p)
			{
				int leftvalue = buffer[2*p]>>16;
				double lefttriggerlevel = _left_trigger_level.getValue()-_left_offset.getValue();
				if (lefttrigger == false && leftvalue > lefttriggerlevel && lefttrace[lefttrace_w] <= lefttriggerlevel) {
					lefttrigger = true;
					_left_bin_counter = tracelen-tracelen/2-cast(int)_left_timezero.getValue();
					if (_left_bin_counter <=          1) _left_bin_counter = 1;
					if (_left_bin_counter >= tracelen-1) _left_bin_counter = tracelen-1;
				}
				lefttrace_w+=1;
				//writeln(lefttrace_w," ", _left_bin_counter, "\r");
				if (lefttrace_w == tracelen) {
					lefttrace_w = 0;
				}
				lefttrace[lefttrace_w] = leftvalue;

				if (lefttrigger) {
					if (_left_bin_counter == 0) {
						//writeln("----\r");
						lefttrigger = false;
						for (long i = 0; i < tracelen; ++i) {

							ulong idx = lefttrace_w+i+1;
							while (idx >= tracelen) idx -= tracelen;
							//writeln(i, " ", idx, "\r");
							_channel_left.setBinContent(i, lefttrace[idx]+_left_offset.getValue());
						}
					}
					--_left_bin_counter;
				}


				int rightvalue = buffer[2*p+1]>>16;
				double righttriggerlevel = _right_trigger_level.getValue()-_right_offset.getValue();
				if (righttrigger == false && rightvalue > righttriggerlevel && righttrace[righttrace_w] <= righttriggerlevel) {
					righttrigger = true;
					_right_bin_counter = tracelen-tracelen/2-cast(int)_right_timezero.getValue();
					if (_right_bin_counter <=          1) _right_bin_counter = 1;
					if (_right_bin_counter >= tracelen-1) _right_bin_counter = tracelen-1;
				}
				righttrace_w+=1;
				//writeln(righttrace_w," ", _right_bin_counter, "\r");
				if (righttrace_w == tracelen) {
					righttrace_w = 0;
				}
				righttrace[righttrace_w] = rightvalue;

				if (righttrigger) {
					if (_right_bin_counter == 0) {
						//writeln("----\r");
						righttrigger = false;
						for (long i = 0; i < tracelen; ++i) {

							ulong idx = righttrace_w+i+1;
							while (idx >= tracelen) idx -= tracelen;
							//writeln(i, " ", idx, "\r");
							_channel_right.setBinContent(i, righttrace[idx]+_right_offset.getValue());
						}
					}
					--_right_bin_counter;
				}
				//writeln(sum_l, " ", sum_r, "\r");
			}
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

	string   _itemname;  // our name in the session
	int      _colorIdx;
	string   _filename;
	long     _steps_left; // number of steps to be done
	                   // -1 for unlimited number of steps

	long     _step_counter;

	import hist1;
	Hist1 _channel_left  = null;
	Hist1 _channel_right = null;
	import number;
	Number _left_trigger_level, _left_offset, _left_timezero;
	Number _right_trigger_level, _right_offset, _right_timezero;
	//Number _left_top,  _left_bot;
	//Number _right_top, _right_bot;


	// alsa stuff
	import deimos.alsa.pcm;
	immutable uint                  period_length = 32;     // 32 frames in one period
	immutable uint                  rate          = 192000; // as fast as we can
	immutable uint                  num_channels  = 2;      // stereo
	immutable uint                  tracelen      = 1024;    // number of bins of the histograms showing the trace
	int[tracelen]                   lefttrace;
	ulong 							lefttrace_w = 0;
	bool                            lefttrigger;
	long _left_bin_counter = 0;
	int[tracelen]                   righttrace;
	ulong 							righttrace_w = 0;
	bool                            righttrigger;
	long _right_bin_counter = 0;
	snd_pcm_hw_params_t             *params;
	snd_pcm_t                       *handle;                // a handle to pcm device
	int[num_channels*period_length] buffer;                 // buffer for the sound data
	int rc;                                                 // pcm function return code



}


immutable class SoundScopeFactory : ItemFactory
{
	this(string itemname, string filename, int colorIdx = -1) pure {
		_itemname = itemname;
		_filename = filename;
		_colorIdx = colorIdx;
	}
	override Item getItem() pure {
		return new SoundScope(_itemname, _colorIdx, _filename);
	}
private:
	string    _itemname;
	string    _filename;
	int       _colorIdx;
}
