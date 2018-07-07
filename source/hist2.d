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
	double[] getData(out ulong w, out ulong h);
}

synchronized class Hist2Filesource : Hist2Datasource 
{
	this(string filename) 
	{
		writeln("Hist2Filesource created on filename: ", filename);
		_filename = filename;		
	}

	double[] getData(out ulong w, out ulong h)
	{
		import std.array, std.algorithm, std.stdio, std.conv;
		File file;
		try {
			writeln("opening file ", _filename);
			file = File(_filename);
		} catch (Exception e) {
			try {
				if (!_filename.startsWith('/')) {
					_filename = "/" ~ _filename;
				}
				writeln("opening file ", _filename);
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

	// get fresh data from the underlying source
	override void refresh() 
	{
		//writeln("Hist1Visualizer.refresh called()");
		ulong width, height;
		_bin_data = cast(shared(double[]))_source.getData(width, height);

		_bins_x = cast(uint)width;
		_bins_y = cast(uint)height;
		//mipmap_data();
		if (_bin_data !is null) {
			_bottom = 0;
			_top    = height;
			_left   = 0;
			_right  = width;
		} else {
			_bottom = -1;
			_top    =  1;
			_left   = -1;
			_right  =  1;
		}


		if (_image_surface !is null) {
			(cast(ImageSurface)_image_surface).destroy();
		}
		
		void get_rgb(double c, shared ubyte *rgb) {
			c *= 3;
			if (c == 0) {          rgb[2] =                     rgb[1] =                         rgb[0] = 255; return ;}
			if (c < 1)  {          rgb[2] = 0;                  rgb[1] = cast(ubyte)(255*c);     rgb[0] = 255-cast(ubyte)(255*c); return;}
			if (c < 2)  {c -= 1.0; rgb[2] = cast(ubyte)(255*c); rgb[1] = 255;                    rgb[0] = 0; return;}
			if (c < 3)  {c -= 2.0; rgb[2] = 255;                rgb[1] = 255-cast(ubyte)(255*c); rgb[0] = 0; return;}

			{rgb[2] = 255; rgb[1] = rgb[0] = 0; return ;}
		}

		// fill the _image_surface
			//int stride = Cairo::ImageSurface::format_stride_for_width(format, width);		
		writeln("_bins_x = ", _bins_x);
		auto stride = ImageSurface.formatStrideForWidth(CairoFormat.RGB24, _bins_x);
		writeln("stride = ", stride, "\r");
		_rgb_data = new shared ubyte[_bin_data.length*(stride/_bins_x)];
		double max_bin = maxElement(_bin_data);
		writeln("max_bin = ", max_bin, "\r");
		foreach(idx, bin; _bin_data) {
			ulong rgb_idx = 3*idx;
			auto x = idx%_bins_x;
			auto y = idx/_bins_x;
//			     y = _bins_y - 1 - y;
			import std.math;
			auto _rgb_data_idx = (y)*stride + 4*x;
			//writeln("_rgb_data_idx = " , _rgb_data_idx, "\r");
			//writeln("bin = " , bin, "\r");//[y*stride + x*w + c]
			get_rgb(min(bin,255)/255.0, &_rgb_data[_rgb_data_idx]);
			//_rgb_data[_rgb_data_idx + 0] = cast(ubyte)(255-min(bin,255));
			//_rgb_data[_rgb_data_idx + 1] = cast(ubyte)(255-min(bin,255));
			//_rgb_data[_rgb_data_idx + 2] = cast(ubyte)(255-min(bin,255));
		}


		_image_surface = cast(shared ImageSurface)ImageSurface.createForData(cast(ubyte*)(&_rgb_data[0]), CairoFormat.RGB24, cast(int)_bins_x, cast(int)_bins_y, stride);

		if (_image_surface_pattern !is null) {
			(cast(Pattern)_image_surface_pattern).destroy();
		}
		_image_surface_pattern = cast(shared Pattern)Pattern.createForSurface(cast(ImageSurface)_image_surface);
		(cast(Pattern)_image_surface_pattern).setFilter(CairoFilter.NEAREST);


	}

	override bool getBottomTopInLeftRight(ref double bottom, ref double top, double left, double right, bool logy, bool logx) {
		bottom = _bottom;
		top    = _top;
		return true;
	}

	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx) {
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

		cr.save();
			cr.scale(box._b_x, box._b_y);
			cr.translate(box._a_x/box._b_x,  +box._a_y/box._b_y);
			cr.rectangle(0,0, _right,_top);
			cr.setSource(cast(Pattern)_image_surface_pattern);
			cr.fill();
		cr.restore();
	}


	this(string name, shared Hist2Datasource source)
	{
		super(name);
		_source = /*cast(shared Hist2Datasource)*/source;
	}

	this(string name, double[] bin_data, double left, double right)
	{
		super(name);
		_left = left;
		_right = right;
		this._bin_data = cast(shared double[])bin_data.dup;
		//mipmap_data();
		if (_bin_data.length > 0) {
			_top    = maxElement(_bin_data);
			_bottom = minElement(_bin_data);
		} else {
			_top    =  1;
			_bottom = -1;
		}
	}

	double getBinWidth()
	{
		if (_bin_data is null || _bin_data.length == 0) {
			return double.init;
		}
		return (_right - _left) / _bin_data.length;
	}


private:


	Hist2Datasource _source;
	double[] _bin_data;
	ubyte[] _rgb_data;
	uint _bins_x, _bins_y;
	import cairo.ImageSurface;
	ImageSurface _image_surface; // this contains the RGB data
	import cairo.Pattern, gdk.Cairo;;
	Pattern _image_surface_pattern; // Pattern.createForSurface(_image_surface) 
	                                //  this is created from the RGB data and can be
	                                //   used as a pattern while drawing to a cairo context

	shared string _name;

	alias struct minmax {double min; double max;} ;
}