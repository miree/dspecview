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


immutable class NumberVisualizer : Visualizer 
{
public:
	import cairo.Context, cairo.Surface;
	import view;

	this(double value, int colorIdx, Direction direction) {
		_value = value;
		_colorIdx = colorIdx;
		_direction = direction;
	}

	override int getColorIdx() immutable {
		return _colorIdx;
	}
	override ulong getDim() immutable {
		return 0;
	}
	override void print(int context) immutable {
	}
	override bool needsColorKey() immutable {
		return false;
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
	override bool getZminZmaxInLeftRightBottomTop(out double mi, out double ma, 
	                                     double left, double right, double bottom, double top, 
	                                     bool logz, bool logy, bool logx) immutable
	{
		return false;
	}

private:
	int    _colorIdx;
	double _value;
	Direction _direction;

}
