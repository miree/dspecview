import session;

enum Direction
{
	x,
	y,
}

class Number : Item
{
public:
	this(double value, double delta, bool logscale, int colorIdx, Direction direction ) pure {
		_colorIdx  = colorIdx;
		_value     = value;
		_delta     = delta;
		_logscale  = logscale;
		_direction = direction;
	}

	immutable(Visualizer) createVisualizer() {
		return new immutable(NumberVisualizer)(_value, _colorIdx, _direction);
	}

	override string getTypeString() {
		import std.conv;
		return  "Number " ~ getValue().to!string;
	}

	override int getColorIdx() {
		return _colorIdx;
	}
	override void setColorIdx(int idx) {
		_colorIdx = idx;
	}

	double getValue() {
		if (_delta !is double.init) {
			if (_logscale) {
				import std.math;
				return _value*exp(_delta);
			}
			return _value + _delta;
		}
		return _value;
	}

private:
	int       _colorIdx;
	double    _value;
	double    _delta;   // is needed if the modified value is used by someone else (for life update projections etc.)
	bool      _logscale; // is needed if the delta was determined in logscale window
	Direction _direction;
}

immutable class NumberFactory : ItemFactory
{
	this(double value, double delta, bool logscale, int colorIdx, Direction direction) pure {
		_value = value;
		_delta = delta;
		_logscale = logscale;
		_colorIdx = colorIdx;
		_direction = direction;
	}
	override Item getItem() pure {
		return new Number(_value, _delta, _logscale, _colorIdx, _direction );
	}
private:	
	double    _value;
	double    _delta;   // is needed if the modified value is used by someone else (for life update projections etc.)
	bool      _logscale; // is needed if the delta was determined in logscale window
	int       _colorIdx;
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
			if (logx && _value < 0) {
				return; // we can't do this
			}
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
			if (logy && _value < 0) {
				return; // we can't do this
			}
			if (mouse_action.relevant) {
				cr.setLineWidth(cr.getLineWidth()*2);
			}
			double value = log_y_value_of(_value, logy);
			if (mouse_action.relevant && mouse_action.button_down) {
				value += mouse_action.y_current - mouse_action.y_start;
			}
			drawHorizontalLine(cr, box, value, box.getLeft(), box.getRight());
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
		if (_direction == Direction.x) {
			double value = log_x_value_of(_value, logx, double.init);
			if (value is double.init) {
				return false;
			} else {
				dx = x-value;
			}
		} else {
			double value = log_y_value_of(_value, logy, double.init);
			if (value is double.init) {
				return false;
			} else {
				dy = y-value;
			}
		}
		import std.stdio;
		return true;
	}

	override void mouseButtonDown(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy) immutable
	{
		import std.stdio;
	}
	override void mouseDrag(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy) immutable
	{
		double delta;
		if (_direction == Direction.x) {
			delta = mouse_action.x_current - mouse_action.x_start;
		} else {
			delta = mouse_action.y_current - mouse_action.y_start;
		}
		import std.stdio;

		// create a new item with the updated position
		bool logscale = false;
		if (logx && _direction == Direction.x ||
			logy && _direction == Direction.y) {
			logscale = true;
		} 
		// send an item with the temporary changes
		sessionTid.send(MsgAddItem(mouse_action.itemname, new immutable(NumberFactory)(_value, delta, logscale, _colorIdx, _direction)));
		sessionTid.send(MsgEchoRedrawContent(mouse_action.gui_idx), thisTid);

	}
	override void mouseButtonUp(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy) immutable
	{
		import std.stdio, std.math;
		import logscale;
		double delta;
		if (_direction == Direction.x) {
			delta = mouse_action.x_current - mouse_action.x_start;
		} else {
			delta = mouse_action.y_current - mouse_action.y_start;
		}

		if (logx && _direction == Direction.x ||
			logy && _direction == Direction.y) {
			// send an item with the permanent changes
			sessionTid.send(MsgAddItem(mouse_action.itemname, 
										new immutable(NumberFactory)(_value*exp(delta), double.init, true, _colorIdx, _direction)));
		} else {
			sessionTid.send(MsgAddItem(mouse_action.itemname, 
										new immutable(NumberFactory)(_value+delta, double.init, false, _colorIdx, _direction)));
		}
		sessionTid.send(MsgRequestItemVisualizer(mouse_action.itemname, mouse_action.gui_idx), thisTid);
		sessionTid.send(MsgEchoRedrawContent(mouse_action.gui_idx), thisTid);


	}

private:
	double _value;
	Direction _direction;

}
