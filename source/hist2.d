import session;



//////////////////////////////////////////////////
// Visualizer for 2D Histograms
immutable class Hist2Visualizer : BaseVisualizer 
{
public:
	this() {
		super(0);
		_bin_data    = null;
		_rgb_data    = null;
		_log_rgb_data = null;
		_image_surface_pattern     = null;
		_log_image_surface_pattern = null;
		_left        = _right = double.init;
		_bottom      = _top   = double.init;
		_bins_x      = 0;
		_bins_y      = 0;
		//_mipmap_data = null;
	}
	//this(int colorIdx, double[] data, 
	//	immutable(ubyte[]) rgb_data             , immutable(ubyte[]) log_rgb_data,
	//	immutable(Pattern) image_surface_pattern, immutable(Pattern) log_image_surface_pattern,
	//	ulong width, ulong height, 
	//	double left, double right, double bottom, double top)
	//{
	import cairo.Pattern, gdk.Cairo;
	this(int colorIdx, double[] data, 
		ulong width, ulong height, 
		double left, double right, double bottom, double top)
	{
		super(colorIdx);
		_bin_data = data.idup;
		_bins_x   = width;
		_bins_y   = height;
		_left     = left;
		_right    = right;
		_bottom   = bottom;
		_top      = top;


        // create surface pattern for fast drawing
		import cairo.ImageSurface, cairo.Pattern, gdk.Cairo;
		auto stride = ImageSurface.formatStrideForWidth(CairoFormat.RGB24, cast(int)_bins_x);
		//writeln("stride = ", stride, "\r");
		auto rgb_data = new ubyte[_bin_data.length*(stride/_bins_x)];
		auto log_rgb_data = new ubyte[_bin_data.length*(stride/_bins_x)];

		rgb_data[] = 255;
		log_rgb_data[] = 255;
		import std.algorithm;
		double max_bin = maxElement(_bin_data);
		if (max_bin == 0) max_bin = 1;
		foreach(ulong y; 0.._bins_y) {
			foreach(ulong x; 0.._bins_x) {
				ulong idx = y*_bins_x+x;
				ulong rgb_idx = 3*idx;
				auto bin = _bin_data[idx];
				if (bin == 0) {
					continue;
				}
				import std.math;
				auto rgb_data_idx = (y)*stride + 4*x;


				get_rgb(log(1+bin)/log(max_bin+1), &log_rgb_data[rgb_data_idx]);
				get_rgb(bin/max_bin, &rgb_data[rgb_data_idx]);
			}
		}

		immutable(Pattern) surface_pattern(ubyte* rgb_data, int nx, int ny, int stride) {
			auto image_surface = ImageSurface.createForData(rgb_data, CairoFormat.RGB24, nx, ny, stride);
			auto image_surface_pattern = Pattern.createForSurface(image_surface);
			image_surface_pattern.setFilter(CairoFilter.NEAREST);
			return cast(immutable(Pattern))image_surface_pattern;
		}

		_rgb_data = cast(immutable ubyte[])rgb_data;
		_log_rgb_data = cast(immutable ubyte[])log_rgb_data;

		_image_surface_pattern     = surface_pattern(cast(ubyte*)(&rgb_data[0]), cast(int)_bins_x, cast(int)_bins_y, stride);
		_log_image_surface_pattern = surface_pattern(cast(ubyte*)(&log_rgb_data[0]), cast(int)_bins_x, cast(int)_bins_y, stride);


		// create mipmaps here
	}

	override ulong getDim() immutable
	{
		return 2;
	}

	override bool needsColorKey() immutable
	{
		return true;
	}

	import cairo.Context, cairo.Surface;
	import view;

	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz, ItemMouseAction mouse_action, VisualizerContext context) immutable
	{
		import primitives;
		//void drawHistogram(T)(ref Scoped!Context cr, ViewBox box, double min, double max, T[] bins, bool logy = true, bool logx = false)
		import std.stdio;
		//writeln("drawHistram(,,",_left,",",_right,")\r");
		if (_bin_data is null) {
			return;
		}
		try {

			import logscale;
			cr.setLineWidth(4.0);
			cr.rectangle(box.transform_box2canvas_x(log_x_value_of(_left  , box, logx)),
						 box.transform_box2canvas_y(log_y_value_of(_bottom, box, logy)),
						 box.transform_box2canvas_x(log_x_value_of(_right , box, logx)) - box.transform_box2canvas_x(log_x_value_of(_left, box, logx)),
						 box.transform_box2canvas_y(log_y_value_of(_top   , box, logy)) - box.transform_box2canvas_y(log_y_value_of(_bottom, box, logy)));
			cr.stroke();
			cr.setSourceRgba(1, 1, 1, 1);
			cr.rectangle(box.transform_box2canvas_x(log_x_value_of(_left  , box, logx)),
						 box.transform_box2canvas_y(log_y_value_of(_bottom, box, logy)),
						 box.transform_box2canvas_x(log_x_value_of(_right , box, logx)) - box.transform_box2canvas_x(log_x_value_of(_left, box, logx)),
						 box.transform_box2canvas_y(log_y_value_of(_top   , box, logy)) - box.transform_box2canvas_y(log_y_value_of(_bottom, box, logy)));
			cr.fill();
			if (logx || logy) {
				//double max_bin = maxElement(_bin_data);

				if (_bin_data is null) {
					return ;
				}
				if (_bin_data.length == 0) {
					return ;
				}
				if (_bottom is double.init || _top is double.init || 
					_left is double.init   || _right is double.init) {
					return ;
				}
				double right = box.getRight();
				double left =  box.getLeft();
				double bottom = box.getBottom();
				double top = box.getTop();
				import std.math;
				if (logx) { // special treatment for logx case
					right = exp(right);
					left = exp(left);
				}
				if (logy) { // special treatment for logy case
					bottom = exp(bottom);
					top = exp(top);
				}
				// transform into bin numbers
				left    = (left-_left)/getBinWidth();
				right   = (right-_left)/getBinWidth();
				bottom  = (bottom-_bottom)/getBinHeight();
				top     = (top-_bottom)/getBinHeight();


				import std.algorithm, std.stdio;
				import logscale;
				double minimum, maximum;
				bool initialize = true;
				int leftbin   = cast(int)(max(left,0));
				int rightbin  = cast(int)(min(right,_bins_x));
				int bottombin = cast(int)(max(bottom,0));
				int topbin    = cast(int)(min(top,_bins_y));
				//writeln("bins:", leftbin, " ", rightbin, " ", bottombin, " ", topbin, "\r");
				if (leftbin > rightbin) return ;
				if (bottombin > topbin) return ;

				foreach(j ; bottombin..topbin+1) {
					if (j < 0) {
						continue;
					}
					if (j >= _bins_y) {
						break;
					}
					foreach(i ; leftbin..rightbin+1){
						//writeln(i, " ", j );
						if (i < 0) {
							continue;
						}
						if (i >= _bins_x) {
							break;
						}
						import std.algorithm;
						if (!(i >= 0 && i < _bins_x)) { writeln("Hist2Visualizer.draw assertion (i >= 0 && i < _bins_x) failed"); }
						if (!(j >= 0 && j < _bins_y)) { writeln("Hist2Visualizer.draw assertion (j >= 0 && j < _bins_y) failed"); }
						ulong idx = _bins_x*j+i;
						double value = _bin_data[idx++];
						if (value == 0) {
							continue;
						}

						int x_idx = i;
						int y_idx = j;

						double box_x      = log_x_value_of(_left+getWidth()*(x_idx)/_bins_x,box,logx);
						double box_xplus1 = log_x_value_of(_left+getWidth()*(x_idx+1)/_bins_x,box,logx);
						double box_y      = log_y_value_of(_bottom+getHeight()*(y_idx)/_bins_y,box,logy);
						double box_yplus1 = log_y_value_of(_bottom+getHeight()*(y_idx+1)/_bins_y,box,logy);


						double x      = box.transform_box2canvas_x(box_x);
						double xplus1 = box.transform_box2canvas_x(box_xplus1);
						double y      = box.transform_box2canvas_y(box_y);
						double yplus1 = box.transform_box2canvas_y(box_yplus1);
						double color  = box.transform_box2canvas_z(log_z_value_of(value,logz));
						//writeln("value=",value, " -> color=",color,"   zrange=",box.getZrange(),"\r");
						double width = xplus1-x;
						double height = yplus1-y;
						ubyte[3] rgb;
						if (logz) {
							import std.math;
							//get_rgb(log(value+1.0)/log(max_bin+1.0), cast(shared ubyte*)&rgb[0]);
							get_rgb(color, &rgb[0]);
						} else {
							//get_rgb(value/max_bin, cast(shared ubyte*)&rgb[0]);
							get_rgb(color, &rgb[0]);
						}
						cr.setSourceRgba(rgb[2]/255.0, rgb[1]/255.0, rgb[0]/255.0, 1);
						cr.rectangle(x-0.25, y+0.25, width+0.5, height-0.5);
						cr.fill();
					}
				}


			} else {
				cr.save();
					cr.scale(box._b_x*getBinWidth(), box._b_y*getBinHeight());
					cr.translate(_left/getBinWidth()+box._a_x/(box._b_x*getBinWidth()),  _bottom/getBinHeight()+box._a_y/(box._b_y*getBinHeight()));
					cr.rectangle(0,0,_bins_x, _bins_y);
					if (logz) {
						cr.setSource(cast(Pattern)_log_image_surface_pattern);
					} else {
						cr.setSource(cast(Pattern)_image_surface_pattern);
					}
					cr.fill();
				cr.restore();
			}			


			
		} catch(Exception e) {
			writeln ("there was an Exception: ", e.file, ":", e.line, " -> ", e.msg, "\r");
		}
	}

	double getBinWidth() immutable
	{
		//assert(_bin_data !is null);
		return (_right - _left) / _bins_x;
	}
	double getBinHeight() immutable
	{
		//assert(_bin_data !is null);
		return (_top - _bottom) / _bins_y;
	}
	double getWidth() immutable
	{
		return _right-_left;
	}
	double getHeight() immutable
	{
		return _top-_bottom;
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
	override bool getZminZmaxInLeftRightBottomTop(out double mi, out double ma, 
	                                     double left, double right, double bottom, double top, 
	                                     bool logz, bool logy, bool logx) immutable
	{
		if (_bin_data is null) {
			return false;
		}
		if (_bin_data.length == 0) {
			return false;
		}
		if (_bottom is double.init || _top is double.init || 
			_left is double.init   || _right is double.init) {
			return false;
		}

		import std.math;
		if (logx) { // special treatment for logx case
			right = exp(right);
			left = exp(left);
		}
		if (logy) { // special treatment for logy case
			bottom = exp(bottom);
			top = exp(top);
		}
		// transform into bin numbers
		left    = (left-_left)/getBinWidth();
		right   = (right-_left)/getBinWidth();
		bottom  = (bottom-_bottom)/getBinHeight();
		top     = (top-_bottom)/getBinHeight();


		import std.algorithm, std.stdio;
		import logscale;
		double minimum, maximum;
		bool initialize = true;
		int leftbin   = cast(int)(max(left,0));
		int rightbin  = cast(int)(min(right,_bins_x));
		int bottombin = cast(int)(max(bottom,0));
		int topbin    = cast(int)(min(top,_bins_y));
		//writeln("bins:", leftbin, " ", rightbin, " ", bottombin, " ", topbin, "\r");
		if (leftbin > rightbin) return false;
		if (bottombin > topbin) return false;

		foreach(j ; bottombin..topbin+1) {
			if (j < 0) {
				continue;
			}
			if (j >= _bins_y) {
				break;
			}
			foreach(i ; leftbin..rightbin+1){
				//writeln(i, " ", j );
				if (i < 0) {
					continue;
				}
				if (i >= _bins_x) {
					break;
				}
				import std.algorithm;
				if(!(i >= 0 && i < _bins_x)) { 
					writeln ("getZminZmaxInLeftRightBottomTop() (i >= 0 && i < _bins_x) was violated\r");
				}
				if(!(j >= 0 && j < _bins_y)) { 
					writeln ("getZminZmaxInLeftRightBottomTop() (j >= 0 && j < _bins_y) was violated\r");
				}
				ulong idx = _bins_x*j+i;
				if ((logz && (_bin_data[idx] > 0)) || !logz) {
					if (initialize) {
						minimum = log_z_value_of(_bin_data[idx], logz);
						maximum = log_z_value_of(_bin_data[idx], logz);
						initialize = false;
					}
					minimum = min(minimum, log_z_value_of(_bin_data[idx], logz));
					maximum = max(maximum, log_z_value_of(_bin_data[idx], logz));
				}
			}
		}



		//writeln("getZminZmaxInLeftRightBottomTop done\r");
		if (!initialize) {
			mi = minimum;
			ma = maximum;
			//writeln("zmin=",zmin, "  zmax=",zmax,"\r");
			//writeln("exp(zmin)=",exp(zmin), "  exp(zmax)=",exp(zmax),"\r");
			return true;
		}
		return false;

	}

	override bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable
	{
		if (_bin_data is null) {
			return false;
		}
		if (_bin_data.length == 0) {
			return false;
		}
		if (_bottom is double.init || _top   is double.init || 
			_left   is double.init || _right is double.init) {
			return false;
		}
		import logscale;
		bottom = log_y_value_of(_bottom, logy, getBinHeight()/2.0); // set the default_zero to half the bin size
		top    = log_y_value_of(_top   , logy, getBinHeight()/2.0);
		left   = log_x_value_of(_left  , logx, getBinWidth()/2.0);
		right  = log_x_value_of(_right , logx, getBinWidth()/2.0);
		return true;
	}


	static void get_rgb(double c, ubyte *rgb) {
		if (c < 0) c = 0;
		c *= 3;
		//if (c == 0) {          rgb[2] =                     rgb[1] =                         rgb[0] = 255; return ;}
		if (c < 1)  {          rgb[2] = 0;                  rgb[1] = cast(ubyte)(255*c);     rgb[0] = 255-cast(ubyte)(255*c); return;}
		if (c < 2)  {c -= 1.0; rgb[2] = cast(ubyte)(255*c); rgb[1] = 255;                    rgb[0] = 0; return;}
		if (c < 3)  {c -= 2.0; rgb[2] = 255;                rgb[1] = 255-cast(ubyte)(255*c); rgb[0] = 0; return;}

		{rgb[2] = 255; rgb[1] = rgb[0] = 0; return ;}
	}


private:




private: // state	
	double[] _bin_data;
	double _left, _right;
	double _bottom, _top;
	ulong _bins_x, _bins_y;

	// mipmap data // TODO implement
	struct MinMax {double min; double max;} ;
	//MinMax[][] _mipmap_data;

	ubyte[] _rgb_data;
	ubyte[] _log_rgb_data;

	import cairo.Pattern, gdk.Cairo;
	Pattern _image_surface_pattern;
	Pattern _log_image_surface_pattern;
}

