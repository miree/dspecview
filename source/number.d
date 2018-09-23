import session;

enum Direction
{
	x,
	y,
}

class Number : Item
{
public:
	this(double value, double delta, int colorIdx, Direction direction ) {
		_colorIdx  = colorIdx;
		_value     = value;
		_delta     = delta;
		_direction = direction;
	}

	immutable(Visualizer) createVisualizer() {
		return new immutable(NumberVisualizer)(_value, _colorIdx, _direction);
	}

	string getTypeString() {
		import std.conv;
		if (_delta is double.init) {
			return "Number " ~ _value.to!string;
		}
		return  "Number " ~ (_value+_delta).to!string;
	}

	int getColorIdx() {
		return _colorIdx;
	}

	double getValue() {
		if (_delta !is double.init) {
			return _value + _delta;
		}
		return _value;
	}

private:
	int       _colorIdx;
	double    _value;
	double    _delta;   // is needed if the modified value is used by someone else (for life update projections etc.)
	Direction _direction;
}


immutable class NumberVisualizer : BaseVisualizer 
{
public:
	import std.concurrency;
	import cairo.Context, cairo.Surface;
	import view, logscale;

	this(double value, int colorIdx, Direction direction) {
		super(colorIdx);
		_value = value;
		_direction = direction;
	}
	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz, ItemMouseAction mouse_action) immutable
	{
		import std.stdio;
		import logscale, primitives;
		if (_direction == Direction.x) {
			if (mouse_action.relevant) {
				cr.setLineWidth(cr.getLineWidth()*2);
			}
			double value = log_x_value_of(_value, logx);
			if (mouse_action.relevant && mouse_action.button_down) {
				value += mouse_action.x_current - mouse_action.x_start;
			}
			drawVerticalLine(cr, box, value, box.getBottom(), box.getTop());
		} 
		if (_direction == Direction.y) {
			drawHorizontalLine(cr, box, log_y_value_of(_value, logy), box.getLeft(), box.getRight());
		} 
		cr.stroke();
	}
	override bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable
	{
		if (_direction == Direction.x) {
			left = right = log_x_value_of(_value, logx);
			return true;
		}
		return false;
	}
	override bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable
	{
		if (_direction == Direction.y) {
			bottom = top = log_y_value_of(_value, logy);
			return true;
		}
		return false;
	}
	override bool mouseDistance(out double dx, out double dy, double x, double y, bool logx, bool logy) immutable
	{
		import std.math;
		import logscale;
		double value = log_x_value_of(_value, logx, double.init);
		if (value is double.init) {
			return false;
		} else {
			dx = x-value;
		}
		import std.stdio;
		return true;
	}

	override void mouseButtonDown(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy) immutable
	{
		import std.stdio;
		writeln("cl-\r");
	}
	override void mouseDrag(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy) immutable
	{
		double delta = mouse_action.x_current - mouse_action.x_start;
		//_delta = delta;
		import std.stdio;
		writeln("send msg ", _value, " ", delta, "\r");
		sessionTid.send(MsgAddNumber(mouse_action.itemname, _value, delta, mouse_action.gui_idx, _colorIdx), thisTid);
	}
	override void mouseButtonUp(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy) immutable
	{
		import std.stdio, std.math;
		import logscale;
		writeln("-ick\r");
		writeln("xstart ", mouse_action.x_start,"\r");
		writeln("xcurrent ", mouse_action.x_current,"\r");
		double delta = mouse_action.x_current - mouse_action.x_start;
		writeln("send msg ", _value, " ", double.init, "\r");
		if (logx) {
			sessionTid.send(MsgAddNumber(mouse_action.itemname, _value*exp(delta), double.init, mouse_action.gui_idx, _colorIdx), thisTid);
		} else {
			sessionTid.send(MsgAddNumber(mouse_action.itemname, _value+delta, double.init, mouse_action.gui_idx, _colorIdx), thisTid);
		}

	}

private:
	double _value;
	Direction _direction;

}
