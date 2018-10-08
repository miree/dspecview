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

		double x0_canvas, y0_canvas;
		foreach(idx, point; _points) {
			double x = log_x_value_of(point.x, logx);
			double y = log_y_value_of(point.y, logy);

			//writeln("mouse_action.relevant=",mouse_action.relevant,"\r");
			//writeln("mouse_action.button_down=", mouse_action.button_down,"\r");
			//writeln("visu_context.selcted_index=", visu_context.selcted_index,"\r");
			if (mouse_action.relevant && mouse_action.button_down) {
				if (visu_context.selcted_index == idx) {
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
				if (visu_context.selcted_index == idx) {
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
		}
		if (min_dist !is double.init) {
			dr = min_dist;
			if (visu_context.selcted_index != min_idx) {
				visu_context.changed = true;
			}
			visu_context.selcted_index = min_idx;
		}
		return false;
	}

	override void mouseButtonDown(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
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
			if (visu_context.selcted_index == idx) {
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
			if (visu_context.selcted_index == idx) {
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

		sessionTid.send(MsgAddItem(mouse_action.itemname, 
									new immutable(PolyGateFactory)(new_points, new_deltas, logx, logy, _colorIdx)));

		sessionTid.send(MsgRequestItemVisualizer(mouse_action.itemname, mouse_action.gui_idx), thisTid);
		sessionTid.send(MsgEchoRedrawContent(mouse_action.gui_idx), thisTid);
	}
	override void deleteKeyPressed(Tid sessionTid, ItemMouseAction mouse_action, VisualizerContext context) immutable
	{
		auto visu_context = cast(PolyGateVisualizerContext)context;
		if (mouse_action.relevant && visu_context.selcted_index >= 0) {
			import std.stdio;
			//writeln("polygate delete on index ", visu_context.selcted_index, "\r");

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

	bool inside(double x, double y) {
		bool is_inside = false;
		PolyPoint p1 = _points[$-1];
		foreach(p2; _points) {
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

