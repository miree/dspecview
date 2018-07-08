import drawable;
import view;
import primitives;
import logscale;

import cairo.Context;
import cairo.Surface;
import std.algorithm, std.stdio;


// this can be asked for data and can be 
// represented by a real dataset or just 
// a link to a file from which the data is
// read on request
synchronized interface Hist2Datasource
{
	double[] getData(out ulong w, out ulong h, out double hist_left, out double hist_right, out double hist_bottom, out double hist_top);
}

synchronized class Hist2Filesource : Hist2Datasource 
{
	this(string filename) 
	{
		writeln("Hist2Filesource created on filename: ", filename);
		_filename = filename;		
	}


	double[] getData(out ulong w, out ulong h, out double hist_left, out double hist_right, out double hist_bottom, out double hist_top)
	{
		import std.array, std.algorithm, std.stdio, std.conv;
		File file;
		try {
			//writeln("opening file ", _filename);
			file = File(_filename);
		} catch (Exception e) {
			try {
				if (!_filename.startsWith('/')) {
					_filename = "/" ~ _filename;
				}
				//writeln("opening file ", _filename);
				file = File(_filename);
			} catch (Exception e) {
				writeln("unable to open file ", _filename);
				return null;
			}
		} 
		double[] result;
		try {
			ulong max_width = 0;
			import std.algorithm;
			foreach(line; file.byLine)	{
				if (line.startsWith("#")) { // read meta information left offset and bin width
					import std.format;
					//# 2 500 0 0 3 500 1 0 3
					int dim;
					int    xbins;
					string xname;
					double left, xbinwidth;
					int    ybins;
					string yname;
					double bottom, ybinwidth;

					try {
						line.formattedRead("# %s %s %s %s %s %s %s %s %s", dim, xbins, xname, left, xbinwidth, ybins, yname, bottom, ybinwidth);
						hist_left = left;
						hist_right = left+xbinwidth*xbins;
						//writeln("left = ", hist_left, " right = ", hist_right, "\r");
						hist_bottom = bottom;
						hist_top = bottom+ybinwidth*ybins;
						//writeln("bottom = ", hist_bottom, " top = ", hist_top, "\r");
					} catch (Exception e) {
						writeln("Exception caught\r");
					}

				}
				if (!line.startsWith("#") && line.length > 0) {
					auto line_split = split(line.dup(), " ");
					ulong width = 0;
					foreach(number; line_split) {
						if (number.length > 0) {
							result ~= to!double(number);
							++width;
						}
					}
					max_width = max(max_width, width);
				}
			}
			if (result.length % max_width == 0) {
				w = max_width;
				h = result.length / w;
				writeln("can determine the width and height: ", w, " ", h, "\r");
			} else {
				writeln("cannot determine width and height. max_width = ", max_width, "   result.length = ", result.length, "\r");
				w = max_width;
				h = 1;
			}
		} catch (Exception e) {
			writeln("there was an Exception ");
		}
		if (hist_left is double.init) hist_left = 0;
		if (hist_right is double.init) hist_right = w;
		if (hist_bottom is double.init) hist_bottom = 0;
		if (hist_top is double.init) hist_top = h;
		//writeln(file.byLine().map!(a => to!double(a)).array);
		return result;
	}
private:
	string _filename;
}

synchronized class Hist2Visualizer : Drawable 
{
	override string getType()   {
		return "Hist2";
	}
	override string getInfo() {
		return "empty 2d histogram";
	}

	override int getDim() {
		return 2;
	}

	// 0 <= c <= 1 is mapped to a color
	void get_rgb(double c, shared ubyte *rgb) {
		c *= 3;
		if (c == 0) {          rgb[2] =                     rgb[1] =                         rgb[0] = 255; return ;}
		if (c < 1)  {          rgb[2] = 0;                  rgb[1] = cast(ubyte)(255*c);     rgb[0] = 255-cast(ubyte)(255*c); return;}
		if (c < 2)  {c -= 1.0; rgb[2] = cast(ubyte)(255*c); rgb[1] = 255;                    rgb[0] = 0; return;}
		if (c < 3)  {c -= 2.0; rgb[2] = 255;                rgb[1] = 255-cast(ubyte)(255*c); rgb[0] = 0; return;}

		{rgb[2] = 255; rgb[1] = rgb[0] = 0; return ;}
	}
	// get fresh data from the underlying source
	override void refresh() 
	{
		//writeln("Hist1Visualizer.refresh called()");
		ulong width, height;
		double left, right, bottom, top;
		_bin_data = cast(shared(double[]))_source.getData(width, height, left, right, bottom, top );

		_bins_x = cast(uint)width;
		_bins_y = cast(uint)height;

		//writeln("width = " , width, "   height = ", height, "\r");
		//writeln("left = ", left, " right = ", right, "\r");
		//writeln("bottom = ", bottom, " top = ", top, "\r");
		//mipmap_data();
		if (_bin_data !is null) {
			_bottom = bottom;
			_top    = top;
			_left   = left;
			_right  = right;
		} else {
			_bottom = -1;
			_top    =  1;
			_left   = -1;
			_right  =  1;
		}

		if (_image_surface !is null) {
			(cast(ImageSurface)_image_surface).destroy();
		}

		// fill the _image_surface
			//int stride = Cairo::ImageSurface::format_stride_for_width(format, width);		
		//writeln("_bins_x = ", _bins_x);
		auto stride = ImageSurface.formatStrideForWidth(CairoFormat.RGB24, _bins_x);
		//writeln("stride = ", stride, "\r");
		_rgb_data = new shared ubyte[_bin_data.length*(stride/_bins_x)];
		_log_rgb_data = new shared ubyte[_bin_data.length*(stride/_bins_x)];
		double max_bin = maxElement(_bin_data);
		//writeln("max_bin = ", max_bin, "\r");
		foreach(idx, bin; _bin_data) {
			ulong rgb_idx = 3*idx;
			auto x = idx%_bins_x;
			auto y = idx/_bins_x;
//			     y = _bins_y - 1 - y;
			import std.math;
			auto _rgb_data_idx = (y)*stride + 4*x;
			//writeln("_rgb_data_idx = " , _rgb_data_idx, "\r");
			//writeln("bin = " , bin, "\r");//[y*stride + x*w + c]
			get_rgb(log(1+bin)/log(max_bin+1), &_log_rgb_data[_rgb_data_idx]);
			get_rgb(bin/max_bin, &_rgb_data[_rgb_data_idx]);
			//_rgb_data[_rgb_data_idx + 0] = cast(ubyte)(255-min(bin,255));
			//_rgb_data[_rgb_data_idx + 1] = cast(ubyte)(255-min(bin,255));
			//_rgb_data[_rgb_data_idx + 2] = cast(ubyte)(255-min(bin,255));
		}


		_image_surface = cast(shared ImageSurface)ImageSurface.createForData(cast(ubyte*)(&_rgb_data[0]), CairoFormat.RGB24, cast(int)_bins_x, cast(int)_bins_y, stride);
		if (_image_surface_pattern !is null) {
			(cast(Pattern)_image_surface_pattern).destroy();
		}
		_image_surface_pattern = cast(shared Pattern)Pattern.createForSurface(cast(ImageSurface)_image_surface);
		(cast(Pattern)_image_surface_pattern).setFilter(CairoFilter.BILINEAR);

		_log_image_surface = cast(shared ImageSurface)ImageSurface.createForData(cast(ubyte*)(&_log_rgb_data[0]), CairoFormat.RGB24, cast(int)_bins_x, cast(int)_bins_y, stride);
		if (_log_image_surface_pattern !is null) {
			(cast(Pattern)_log_image_surface_pattern).destroy();
		}
		_log_image_surface_pattern = cast(shared Pattern)Pattern.createForSurface(cast(ImageSurface)_log_image_surface);
		(cast(Pattern)_log_image_surface_pattern).setFilter(CairoFilter.BILINEAR);


	}

	override bool getBottomTopInLeftRight(ref double bottom, ref double top, double left, double right, bool logy, bool logx) {
		bottom = log_y_value_of(_bottom, logy);
		top    = log_y_value_of(_top, logy);
		return true;
	}

	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz) {
		//writeln("Hist1Visualizer.draw() called\r");
		if (_bin_data is null) {
			refresh();
		}
		//writeln("bins = ", _bin_data[0].length, "\r");

		//writeln("pixel width = ", box.get_pixel_width() , "\r");
		auto pixel_width = box.get_pixel_width();
		auto bin_width = 1;
		//if (bin_width > pixel_width || logx) { // there is no mipmap impelemntation for logx histogram drawing
			//drawHistogram(cr,box, 0,_bin_data.length, _bin_data, logy, logx);
		//} 

		if (logy || logx) {
			// log drawing has to be done bin by bin for now... only the bins != 0
			cr.setSourceRgba(1, 1, 1, 1);
			cr.rectangle(box.transform_box2canvas_x(log_x_value_of(getLeft, box, logx)),
						 box.transform_box2canvas_y(log_y_value_of(getBottom, box, logy)),
						 box.transform_box2canvas_x(log_x_value_of(getRight, box, logx)) - box.transform_box2canvas_x(log_x_value_of(getLeft, box, logx)),
						 box.transform_box2canvas_y(log_y_value_of(getTop, box, logy)) - box.transform_box2canvas_y(log_y_value_of(getBottom, box, logy)));
			cr.fill();
			double max_bin = maxElement(_bin_data);
			//writeln("max_bin = ", max_bin, "\r");
			ulong idx = 0;//y_idx*_bins_x+x_idx;
			foreach(y_idx; 0.._bins_y) {
				foreach(x_idx; 0.._bins_x) {
					double value = _bin_data[idx++];
					if (value == 0) {
						continue;
					}
					//writeln("value = ", value, "\r");
					double x      = box.transform_box2canvas_x(log_x_value_of(getLeft+getWidth*(x_idx)/_bins_x,box,logx));
					double xplus1 = box.transform_box2canvas_x(log_x_value_of(getLeft+getWidth*(x_idx+1)/_bins_x,box,logx));
					double y      = box.transform_box2canvas_y(log_y_value_of(getBottom+getHeight*(y_idx)/_bins_y,box,logy));
					double yplus1 = box.transform_box2canvas_y(log_y_value_of(getBottom+getHeight*(y_idx+1)/_bins_y,box,logy));
					double width = xplus1-x;
					double height = yplus1-y;
					ubyte[3] rgb;
					if (logz) {
						import std.math;
						get_rgb(log(value+1.0)/log(max_bin+1.0), cast(shared ubyte*)&rgb[0]);
					} else {
						get_rgb(value/max_bin, cast(shared ubyte*)&rgb[0]);
					}
					//writeln("rgb, ", value , " ",rgb[2], " ",rgb[1], " ", rgb[0], "\r");
					cr.setSourceRgba(rgb[2]/255.0, rgb[1]/255.0, rgb[0]/255.0, 1);
					//cr.setSourceRgba(255, 0, 0, 1);
					cr.rectangle(x,y, width,height);
					cr.fill();
				}
			}

		} else {
			// linear drawing can be done very fast using the image surface pattern
			cr.save();
				//cr.scale(0.5, 1);
				cr.scale(box._b_x*getBinWidth(), box._b_y*getBinHeight());
				cr.translate(getLeft()/getBinWidth()+box._a_x/(box._b_x*getBinWidth()),  getBottom()/getBinHeight()+box._a_y/(box._b_y*getBinHeight()));
				//cr.rectangle(getLeft,getBottom, getRight-getLeft,getTop-getBottom);
				cr.rectangle(0,0,_bins_x, _bins_y);
				//writeln("get: ", getLeft , " ", getRight, " ", getBottom, " " , getTop, "\r");
				//cr.setSourceRgba(1, 0, 0, 1);
				if (logz) {
					cr.setSource(cast(Pattern)_log_image_surface_pattern);
				} else {
					cr.setSource(cast(Pattern)_image_surface_pattern);
				}
				cr.fill();
			cr.restore();
		}
	}


	this(string name, shared Hist2Datasource source)
	{
		super(name);
		_source = /*cast(shared Hist2Datasource)*/source;
	}



	double getBinWidth()
	{
		if (_bin_data is null || _bins_x == 0) {
			return double.init;
		}
		return (_right - _left) / _bins_x;
	}
	double getBinHeight()
	{
		if (_bin_data is null || _bins_y == 0) {
			return double.init;
		}
		return (_top - _bottom) / _bins_y;
	}


private:


	Hist2Datasource _source;
	double[] _bin_data;
	ubyte[] _rgb_data;
	ubyte[] _log_rgb_data;
	uint _bins_x, _bins_y;
	import cairo.ImageSurface;
	ImageSurface _image_surface; // this contains the RGB data
	ImageSurface _log_image_surface; // this contains the RGB data in logscale
	import cairo.Pattern, gdk.Cairo;;
	Pattern _image_surface_pattern; // Pattern.createForSurface(_image_surface) 
	                                //  this is created from the RGB data and can be
	                                //   used as a pattern while drawing to a cairo context
	Pattern _log_image_surface_pattern; // same only with log color code	                           

	shared string _name;

	alias struct minmax {double min; double max;} ;
}