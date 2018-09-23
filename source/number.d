import session;

enum Direction
{
	x,
	y,
}

class Number : Item
{
public:
	this(double value, int colorIdx, Direction direction ) {
		_colorIdx  = colorIdx;
		_value     = value;
		_direction = direction;
	}

	immutable(Visualizer) createVisualizer() {
		return new immutable(NumberVisualizer)(_value, _colorIdx, _direction);
	}

	string getTypeString() {
		import std.conv;
		return "Number " ~ _value.to!string;
	}

	int getColorIdx() {
		return _colorIdx;
	}

private:
	int       _colorIdx;
	double    _value;
	Direction _direction;
}


immutable class NumberVisualizer : BaseVisualizer 
{
public:
	import cairo.Context, cairo.Surface;
	import view;

	this(double value, int colorIdx, Direction direction) {
		super(colorIdx);
		_value = value;
		_direction = direction;
	}
	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz) immutable
	{
		import std.stdio;
		import logscale, primitives;
		drawVerticalLine(cr, box, _value, box.getBottom(), box.getTop());
		cr.stroke();
	}
	override bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable
	{
		if (_direction == Direction.x) {
			left = right = _value;
			return true;
		}
		return false;
	}
	override bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable
	{
		if (_direction == Direction.y) {
			bottom = top = _value;
			return true;
		}
		return false;
	}
	override double mouseMotionDistance(double x, double y) immutable
	{
		import std.math;
		double distance = abs(x-_value);
		import std.stdio;
		writeln("mouse distance = ", distance, "\r");
		return distance;
	}
private:
	double _value;
	Direction _direction;

}
