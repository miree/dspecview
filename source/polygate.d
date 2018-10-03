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
		return "Polygate ";
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
	int selcted_index;
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
	}
	override bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable
	{
		return false;
	}
	override bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable
	{
		return false;
	}
	override bool mouseDistance(out double dx, out double dy, double x, double y, bool logx, bool logy, VisualizerContext context) immutable
	{
		auto visu_context = cast(PolyGateVisualizerContext)context;
		import std.math, std.algorithm;
		import logscale;
		return false;
	}

	override void mouseButtonDown(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
		import std.stdio;
	}
	override void mouseDrag(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
		auto visu_context = cast(PolyGateVisualizerContext)context;
	}
	override void mouseButtonUp(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
		auto visu_context = cast(PolyGateVisualizerContext)context;
	}

	override VisualizerContext createContext() {
		//import std.stdio;
		//writeln("Gate1VisualizerContext created\r");
		return new PolyGateVisualizerContext;
	}

	override bool isInteractive() {
		return true;
	}

private:
	PolyPoint[] _points;
}
