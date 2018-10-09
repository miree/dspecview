import session;

struct PolyPoint 
{
	double x,y;
}

class PolyGate : Item
{
public:
	this(PolyPoint[] points, PolyPoint[] deltas, bool logx, bool logy, int colorIdx ) pure {
		_colorIdx  = colorIdx;
		_points    = points;
		_deltas    = deltas;
		_logx      = logx;
		_logy      = logy;
	}

	immutable(Visualizer) createVisualizer() {
		return new immutable(PolyGateVisualizer)(_points, _colorIdx);
	}

	override string getTypeString() {
		import std.conv;
		string result = "Polygate ";
		foreach(point; _points) {
			result ~= point.x.to!string ~ "," ~ point.y.to!string ~ " ";
		}
		return result;
	}

	override int getColorIdx() {
		return _colorIdx;
	}
	override void setColorIdx(int idx) {
		_colorIdx = idx;
	}

private:
	int         _colorIdx;
	PolyPoint[] _points;
	PolyPoint[] _deltas;
	bool        _logx;
	bool        _logy;
}

immutable class PolyGateFactory : ItemFactory
{
	this(PolyPoint[] points, PolyPoint[] deltas, bool logx, bool logy, int colorIdx) pure {
		_points    = points.dup;
		_deltas    = deltas.dup;
		_logx      = logx;
		_logy      = logy;
		_colorIdx  = colorIdx;
	}
	override Item getItem() pure {
		return new PolyGate(_points.dup, _deltas.dup, _logx, _logy, _colorIdx);
	}
private:	
	int         _colorIdx;
	PolyPoint[] _points;
	PolyPoint[] _deltas;
	bool        _logx;
	bool        _logy;
}

class PolyGateVisualizerContext : VisualizerContext
{
	int selcted_index = -1;
}

immutable class PolyGateVisualizer : BaseVisualizer 
{
public:
	import std.concurrency;
	import cairo.Context, cairo.Surface;
	import view, logscale;

	this(PolyPoint[] points, int colorIdx) {
		super(colorIdx);
		_points = points.idup;
	}
	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz, ItemMouseAction mouse_action, VisualizerContext context) immutable
	{
		auto visu_context = cast(PolyGateVisualizerContext)context;
		import std.stdio;
		immutable double alpha_value=0.3;   // alpha value of gate visualization
										    // 0 is completely transparent, 1 is completely opaque
		//writeln("draw() : visu_context.selcted_index=",visu_context.selcted_index,"\r");
		double linewidth = cr.getLineWidth();
		import logscale, primitives;

		if (mouse_action.relevant && visu_context.selcted_index == _points.length*2) {
			cr.setLineWidth(linewidth*2);
		} else {
			cr.setLineWidth(linewidth);
		}

		double x0_canvas, y0_canvas;
		foreach(idx, point; _points) {
			double x = log_x_value_of(point.x, logx);
			double y = log_y_value_of(point.y, logy);

			//writeln("mouse_action.relevant=",mouse_action.relevant,"\r");
			//writeln("mouse_action.button_down=", mouse_action.button_down,"\r");
			//writeln("visu_context.selcted_index=", visu_context.selcted_index,"\r");
			if (mouse_action.relevant && mouse_action.button_down) {
				if (visu_context.selcted_index == idx || visu_context.selcted_index == _points.length*2) {
					x += mouse_action.x_current - mouse_action.x_start;
					y += mouse_action.y_current - mouse_action.y_start;
				}
			}
			double x_canvas = box.transform_box2canvas_x(x);
			double y_canvas = box.transform_box2canvas_y(y);

			if (idx == 0) {
				x0_canvas = x_canvas;
				y0_canvas = y_canvas;
				cr.moveTo(x_canvas, y_canvas);			
			} else {
				cr.lineTo(x_canvas, y_canvas);
			}
		}
		cr.lineTo(x0_canvas, y0_canvas);
		cr.stroke();

		// draw inactive points
		auto mean = PolyPoint(0,0);
		int n = 0;
		foreach(idx, point; _points) {
			double x = log_x_value_of(point.x, logx);
			double y = log_y_value_of(point.y, logy);
			auto pixel_width = box.get_pixel_width();
			auto pixel_height = box.get_pixel_height();
			if (mouse_action.relevant && mouse_action.button_down) {
				if (visu_context.selcted_index == idx ||  visu_context.selcted_index == _points.length*2) {
					x += mouse_action.x_current - mouse_action.x_start;
					y += mouse_action.y_current - mouse_action.y_start;
				}
			}
			mean.x += x;
			mean.y += y;
			++n;
			drawFilledBox(cr, box, 
							x-pixel_width*3, 
							y-pixel_height*3, 
							x+pixel_width*3, 
							y+pixel_height*3);
			cr.fill();
		}
		mean.x /= n;
		mean.y /= n;

		// draw active point
		if (mouse_action.relevant && visu_context.selcted_index >= 0 && visu_context.selcted_index < _points.length) {
			auto pixel_width = box.get_pixel_width();
			auto pixel_height = box.get_pixel_height();
			double x = log_x_value_of(_points[visu_context.selcted_index].x, logx);
			double y = log_y_value_of(_points[visu_context.selcted_index].y, logy);
			if (mouse_action.relevant && mouse_action.button_down) {
				x += mouse_action.x_current - mouse_action.x_start;
				y += mouse_action.y_current - mouse_action.y_start;
			}			
			drawFilledBox(cr, box, 
							x-pixel_width*5, 
							y-pixel_height*5, 
							x+pixel_width*5, 
							y+pixel_height*5);
			cr.fill();
		}

		// draw add-a-point option
		foreach(idx, point; _points) {
			auto pixel_width = box.get_pixel_width();
			auto pixel_height = box.get_pixel_height();
			ulong previous_idx = idx;
			if (previous_idx == 0) {
				previous_idx = _points.length-1; 
			} else {
				previous_idx -= 1;
			}
			PolyPoint previous_point = _points[previous_idx];
			double x1 = log_x_value_of(point.x         , logx);
			double y1 = log_y_value_of(point.y         , logy);
			double x2 = log_x_value_of(previous_point.x, logx);
			double y2 = log_y_value_of(previous_point.y, logy);
			if (mouse_action.relevant && mouse_action.button_down) {
				if ( visu_context.selcted_index == idx || visu_context.selcted_index == _points.length*2) {
					x1 += mouse_action.x_current - mouse_action.x_start;
					y1 += mouse_action.y_current - mouse_action.y_start;
				}
				if ( visu_context.selcted_index == previous_idx || visu_context.selcted_index == _points.length*2) {
					x2 += mouse_action.x_current - mouse_action.x_start;
					y2 += mouse_action.y_current - mouse_action.y_start;
				}
			}
			double x = 0.5*(x1+x2);
			double y = 0.5*(y1+y2);
			double size = 3;
			//writeln("selcted_index=",visu_context.selcted_index, "   idx+_points.length=", idx+_points.length,"\r");
			if (mouse_action.relevant && visu_context.selcted_index == idx+_points.length) {
				size = 5;
			}


			drawVerticalLine  (cr, box, x, y-pixel_height*size, y+pixel_height*size);
			drawHorizontalLine(cr, box, y, x-pixel_width*size, x+pixel_width*size);
			cr.stroke();
		}

		// draw filled polygon
		foreach(idx, point; _points) {
			double x = log_x_value_of(point.x, logx);
			double y = log_y_value_of(point.y, logy);

			if (mouse_action.relevant && mouse_action.button_down) {
				if (visu_context.selcted_index == idx ||  visu_context.selcted_index == _points.length*2) {
					x += mouse_action.x_current - mouse_action.x_start;
					y += mouse_action.y_current - mouse_action.y_start;
				}
			}
			double x_canvas = box.transform_box2canvas_x(x);
			double y_canvas = box.transform_box2canvas_y(y);

			if (idx == 0) {
				x0_canvas = x_canvas;
				y0_canvas = y_canvas;
				cr.moveTo(x_canvas, y_canvas);			
			} else {
				cr.lineTo(x_canvas, y_canvas);
			}
		}
		cr.lineTo(x0_canvas, y0_canvas);
		cr.setSourceRgba(1,1,1, alpha_value);
		cr.fill();
	}
	override bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable
	{
		double xmin, xmax;
		foreach(point; _points) {
			double x = log_x_value_of(point.x, logx);
			if (xmin is double.init || x < xmin) {
				xmin = x;
			}
			if (xmax is double.init || x > xmax) {
				xmax = x;
			}
		}
		left  = xmin;
		right = xmax;
		return true;
	}
	override bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable
	{
		double ymin, ymax;
		foreach(point; _points) {
			double y = log_y_value_of(point.y, logy);
			if (ymin is double.init || y < ymin) {
				ymin = y;
			}
			if (ymax is double.init || y > ymax) {
				ymax = y;
			}
		}
		bottom = ymin;
		top    = ymax;
		return true;
	}
	override bool mouseDistance(ViewBox box, out double dx, out double dy, out double dr, double x, double y, bool logx, bool logy, VisualizerContext context) immutable
	{
		auto visu_context = cast(PolyGateVisualizerContext)context;
		import std.math, std.algorithm;
		import logscale;
		int min_idx = -1;
		double min_dist;
		double min_x, max_x;
		double min_y, max_y;

		foreach(idx, point; _points) {
			double px = log_x_value_of(point.x, logx);
			double py = log_y_value_of(point.y, logy);
			double deltax = (x-px) * box._b_x;
			double deltay = (y-py) * box._b_y;
			double dist = sqrt(deltax*deltax + deltay*deltay);
			if (min_dist is double.init || dist < min_dist) {
				min_dist = dist;
				min_idx  = cast(int)idx;
			}
			if (min_x is double.init || min_x > px) {min_x = px;}
			if (max_x is double.init || min_x < px) {min_x = px;}
			if (min_y is double.init || min_y > py) {min_y = py;}
			if (max_y is double.init || max_y > py) {max_y = py;}
		}

		PolyPoint previous_point = _points[$-1];
		foreach(idx, point; _points) {
			double p1x = log_x_value_of(point.x, logx);
			double p1y = log_y_value_of(point.y, logy);
			double p2x = log_x_value_of(previous_point.x, logx);
			double p2y = log_y_value_of(previous_point.y, logy);
			double px = 0.5*(p1x+p2x);
			double py = 0.5*(p1y+p2y);

			double deltax = (x-px) * box._b_x;
			double deltay = (y-py) * box._b_y;
			double dist = sqrt(deltax*deltax + deltay*deltay);
			if (min_dist is double.init || dist < min_dist) {
				min_dist = dist;
				min_idx  = cast(int)(idx+_points.length);
			}
			previous_point = point;
		}

		if (min_dist !is double.init) {
			dr = min_dist;
			if (visu_context.selcted_index != min_idx) {
				// set this to true to initiate a redraw;
				visu_context.changed = true;
			}
			visu_context.selcted_index = min_idx;
		}

		import std.stdio;
		//writeln("min_idx=",visu_context.selcted_index,"\r");

		if (dr > 10 && inside(x,y, logx, logy)) {
			//writeln("inside\r");
			visu_context.selcted_index = cast(int)(_points.length*2);
			if (visu_context.selcted_index != min_idx) {
				// set this to true to initiate a redraw;
				visu_context.changed = true;
			}
			dx = max_x - min_x;
			dy = max_y - min_y;

			return true;
		}

		return false;
	}
	override ulong getDim() immutable {
		return 2; // means undecided (can live with 1d or 2d)
	}
	override void mouseButtonDown(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
		auto visu_context = cast(PolyGateVisualizerContext)context;
		import std.stdio;
		import std.stdio;
		writeln("polygate mouseButtonDown ", visu_context.selcted_index, " " , mouse_action.itemname, "\r");
		//writeln("mouseButtonDown selcted_index=",visu_context.selcted_index,"\r");
		if (visu_context.selcted_index >= _points.length && visu_context.selcted_index < 2*_points.length) {
			PolyPoint[] new_points;
			PolyPoint[] new_deltas;
			PolyPoint previous_point = _points[$-1];
			foreach(idx, point; _points) {
				double x = point.x;
				double y = point.y;
				if (idx+_points.length == visu_context.selcted_index) {
					new_points ~= PolyPoint(0.5*(x+previous_point.x), 0.5*(y+previous_point.y));
					new_deltas ~= PolyPoint(0,0);
				}
				new_points ~= PolyPoint(x,y);
				new_deltas ~= PolyPoint(0,0);
				previous_point = point;
			}

			if (new_points.length >= 3) {
				if (mouse_action.itemname is null ) {
					import std.stdio;
					writeln ("mouseButtonDown itemname is null\r");
				}
				// update all other gui windows
				import gui;
				thisTid.send(MsgAllButMyselfUpdateVisualizer( 
						mouse_action.itemname,
						mouse_action.gui_idx),
						cast(immutable(Visualizer)) new immutable(PolyGateVisualizer)(new_points, _colorIdx));

				// update session
				sessionTid.send(MsgAddItem(mouse_action.itemname, 
											new immutable(PolyGateFactory)(new_points, new_deltas, false, false, _colorIdx)));

				sessionTid.send(MsgRequestItemVisualizer(mouse_action.itemname, mouse_action.gui_idx), thisTid);
				sessionTid.send(MsgEchoRedrawContent(mouse_action.gui_idx), thisTid);
			}
		}
		import std.stdio;
	}
	override void mouseDrag(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
		import std.math;
		auto visu_context = cast(PolyGateVisualizerContext)context;

		PolyPoint[] new_points;
		foreach(idx, point; _points) {
			double x = point.x;
			double y = point.y;
			if (visu_context.selcted_index == idx || visu_context.selcted_index == _points.length*2) {
				if (logx) {
					x *= exp(mouse_action.x_current - mouse_action.x_start);
				} else {
					x += mouse_action.x_current - mouse_action.x_start;
				}
				if (logy) {
					y *= exp(mouse_action.y_current - mouse_action.y_start);
				} else {
					y += mouse_action.y_current - mouse_action.y_start;
				}
			}
			new_points ~= PolyPoint(x,y);
		}

		if (mouse_action.itemname is null ) {
					import std.stdio;
			writeln ("mouseDrag itemname is null\r");
		}
		import gui;
		thisTid.send(MsgAllButMyselfUpdateVisualizer( 
				mouse_action.itemname,
				mouse_action.gui_idx),
				cast(immutable(Visualizer)) new immutable(PolyGateVisualizer)(new_points, _colorIdx));
	}
	override void mouseButtonUp(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
		import std.math;
		auto visu_context = cast(PolyGateVisualizerContext)context;

		PolyPoint[] new_points;
		PolyPoint[] new_deltas;
		foreach(idx, point; _points) {
			double x = point.x;
			double y = point.y;
			if (visu_context.selcted_index == idx || visu_context.selcted_index == _points.length*2) {
				if (logx) {
					x *= exp(mouse_action.x_current - mouse_action.x_start);
				} else {
					x += mouse_action.x_current - mouse_action.x_start;
				}
				if (logy) {
					y *= exp(mouse_action.y_current - mouse_action.y_start);
				} else {
					y += mouse_action.y_current - mouse_action.y_start;
				}
			}
			new_points ~= PolyPoint(x,y);
			new_deltas ~= PolyPoint(0,0);
		}

		if (mouse_action.itemname is null ) {
					import std.stdio;
			writeln ("mouseButtonUp itemname is null\r");
		}

		sessionTid.send(MsgAddItem(mouse_action.itemname, 
									new immutable(PolyGateFactory)(new_points, new_deltas, logx, logy, _colorIdx)));

		sessionTid.send(MsgRequestItemVisualizer(mouse_action.itemname, mouse_action.gui_idx), thisTid);
		sessionTid.send(MsgEchoRedrawContent(mouse_action.gui_idx), thisTid);
	}
	override void deleteKeyPressed(Tid sessionTid, ItemMouseAction mouse_action, VisualizerContext context) immutable
	{
		auto visu_context = cast(PolyGateVisualizerContext)context;
		import std.stdio;
		writeln("polygate delete on index ", visu_context.selcted_index, " " , mouse_action.itemname, "\r");
		if (mouse_action.relevant && visu_context.selcted_index >= 0) {

			PolyPoint[] new_points;
			PolyPoint[] new_deltas;
			foreach(idx, point; _points) {
				double x = point.x;
				double y = point.y;
				if (idx != visu_context.selcted_index) {
					new_points ~= PolyPoint(x,y);
					new_deltas ~= PolyPoint(0,0);
				}
			}

			if (new_points.length >= 3) {
				if (mouse_action.itemname is null ) {
					import std.stdio;
					writeln ("deleteKeyPressed itemname is null\r");
				}
				// update all other gui windows
				import gui;
				thisTid.send(MsgAllButMyselfUpdateVisualizer( 
						mouse_action.itemname,
						mouse_action.gui_idx),
						cast(immutable(Visualizer)) new immutable(PolyGateVisualizer)(new_points, _colorIdx));

				// update session
				sessionTid.send(MsgAddItem(mouse_action.itemname, 
											new immutable(PolyGateFactory)(new_points, new_deltas, false, false, _colorIdx)));


				sessionTid.send(MsgRequestItemVisualizer(mouse_action.itemname, mouse_action.gui_idx), thisTid);
				sessionTid.send(MsgEchoRedrawContent(mouse_action.gui_idx), thisTid);
			}
		}
	}
	override VisualizerContext createContext() {
		//import std.stdio;
		//writeln("Gate1VisualizerContext created\r");
		return new PolyGateVisualizerContext;
	}

	override bool isInteractive() {
		return true;
	}

	bool inside(double x, double y, bool logx, bool logy) {
		bool is_inside = false;
		PolyPoint p1 = _points[$-1];
		p1.x = log_x_value_of(p1.x, logx);
		p1.y = log_y_value_of(p1.y, logy);
		foreach(p; _points) {
			PolyPoint p2;
			p2.x = log_x_value_of(p.x, logx);
			p2.y = log_y_value_of(p.y, logy);
			if ( ((p2.y > y) != (p1.y > y)) &&
			     (x < (p1.x - p2.x) * (y - p2.y) / (p1.y - p2.y) + p2.x) ) {
			    is_inside = !is_inside;
			}
			p1 = p2;
		}
		return is_inside;
	}

private:
	PolyPoint[] _points;
}

