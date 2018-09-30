import session;

enum Direction
{
	x,
	y,
}

class Gate1 : Item
{
public:
	this(double value1, double value2, double delta1, double delta2, bool logscale, int colorIdx, Direction direction ) pure {
		_colorIdx  = colorIdx;
		_value1    = value1;
		_value2    = value2;
		_delta1    = delta1;
		_delta2    = delta2;
		_logscale  = logscale;
		_direction = direction;
		if (getValue1() > getValue2()){
			_value1    = value2;
			_value2    = value1;
			_delta1    = delta2;
			_delta2    = delta1;
		}
	}

	immutable(Visualizer) createVisualizer() {
		return new immutable(Gate1Visualizer)(_value1, _value2, _colorIdx, _direction);
	}

	override string getTypeString() {
		import std.conv;
		return  "Gate (" ~ getValue1().to!string ~ "," ~ getValue2().to!string ~ ")";
	}

	override int getColorIdx() {
		return _colorIdx;
	}
	override void setColorIdx(int idx) {
		_colorIdx = idx;
	}

	double getValue1() pure {
		if (_delta1 !is double.init) {
			if (_logscale) {
				import std.math;
				return _value1*exp(_delta1);
			}
			return _value1 + _delta1;
		}
		return _value1;
	}
	double getValue2() pure {
		if (_delta2 !is double.init) {
			if (_logscale) {
				import std.math;
				return _value2*exp(_delta2);
			}
			return _value2 + _delta2;
		}
		return _value2;
	}

private:
	int       _colorIdx;
	double    _value1;
	double    _value2;
	double    _delta1;   // is needed if the modified value is used by someone else (for life update projections etc.)
	double    _delta2;   // is needed if the modified value is used by someone else (for life update projections etc.)
	bool      _logscale; // is needed if the delta was determined in logscale window
	Direction _direction;
}

immutable class Gate1Factory : ItemFactory
{
	this(double value1, double value2, double delta1, double delta2, bool logscale, int colorIdx, Direction direction) pure {
		_value1 = value1;
		_value2 = value2;
		_delta1 = delta1;
		_delta2 = delta2;
		_logscale = logscale;
		_colorIdx = colorIdx;
		_direction = direction;
	}
	override Item getItem() pure {
		return new Gate1(_value1, _value2, _delta1, _delta2, _logscale, _colorIdx, _direction );
	}
private:	
	double    _value1;
	double    _value2;
	double    _delta1;   // is needed if the modified value is used by someone else (for life update projections etc.)
	double    _delta2;   // is needed if the modified value is used by someone else (for life update projections etc.)
	bool      _logscale; // is needed if the delta was determined in logscale window
	int       _colorIdx;
	Direction _direction;
}

class Gate1VisualizerContext : VisualizerContext
{
	int selcted_index;
}

immutable class Gate1Visualizer : BaseVisualizer 
{
public:
	import std.concurrency;
	import cairo.Context, cairo.Surface;
	import view, logscale;

	this(double value1, double value2, int colorIdx, Direction direction) {
		super(colorIdx);
		_value1 = value1;
		_value2 = value2;
		_direction = direction;
	}
	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz, ItemMouseAction mouse_action, VisualizerContext context) immutable
	{
		auto visu_context = cast(Gate1VisualizerContext)context;
		import std.stdio;
		immutable double alpha_value=0.3;   // alpha value of gate visualization
										    // 0 is completely transparent, 1 is completely opaque
		//writeln("draw() : visu_context.selcted_index=",visu_context.selcted_index,"\r");
		double linewidth = cr.getLineWidth();
		import logscale, primitives;
		if (_direction == Direction.x) {
			if (logx && (_value1 < 0 || _value2 < 0))  {
				return; // TODO: we could do this better ... but later
			}
			double value1 = log_x_value_of(_value1, logx);
			double value2 = log_x_value_of(_value2, logx);
			if (mouse_action.relevant && mouse_action.button_down) {
				if (visu_context.selcted_index == 1 || visu_context.selcted_index == 3) {
					value1 += mouse_action.x_current - mouse_action.x_start;
				}
				if (visu_context.selcted_index == 2 || visu_context.selcted_index == 3) {
					value2 += mouse_action.x_current - mouse_action.x_start;
				}
			}
			if (mouse_action.relevant && (visu_context.selcted_index == 1 || visu_context.selcted_index == 3)) {
				cr.setLineWidth(linewidth*2);
			} else {
				cr.setLineWidth(linewidth);
			}
			drawVerticalLine(cr, box, value1, box.getBottom(), box.getTop());
			cr.stroke();
			if (mouse_action.relevant && (visu_context.selcted_index == 2 || visu_context.selcted_index == 3)) {
				cr.setLineWidth(linewidth*2);
			} else {
				cr.setLineWidth(linewidth);
			}
			drawVerticalLine(cr, box, value2, box.getBottom(), box.getTop());
			cr.stroke();
			cr.setSourceRgba(1,1,1, alpha_value);
			drawFilledBox(cr, box, value1, box.getBottom(), value2, box.getTop());
			cr.fill();
		} 
		if (_direction == Direction.y) {
			if (logy && (_value1 < 0 || _value2 < 0)) {
				return; // we could do this better ... later
			}
			if (mouse_action.relevant) {
				cr.setLineWidth(cr.getLineWidth()*2);
			}
			double value1 = log_y_value_of(_value1, logy);
			double value2 = log_y_value_of(_value2, logy);
			if (mouse_action.relevant && mouse_action.button_down) {
				if (visu_context.selcted_index == 1 || visu_context.selcted_index == 3) {
					value1 += mouse_action.y_current - mouse_action.y_start;
				}
				if (visu_context.selcted_index == 2 || visu_context.selcted_index == 3) {
					value2 += mouse_action.y_current - mouse_action.y_start;
				}
			}
			if (mouse_action.relevant && (visu_context.selcted_index == 1 || visu_context.selcted_index == 3)) {
				cr.setLineWidth(linewidth*2);
			} else {
				cr.setLineWidth(linewidth);
			}
			drawHorizontalLine(cr, box, value1, box.getLeft(), box.getRight());
			cr.stroke();
			if (mouse_action.relevant && (visu_context.selcted_index == 2 || visu_context.selcted_index == 3)) {
				cr.setLineWidth(linewidth*2);
			} else {
				cr.setLineWidth(linewidth);
			}
			drawHorizontalLine(cr, box, value2, box.getLeft(), box.getRight());
			cr.stroke();
			cr.setSourceRgba(1,1,1, alpha_value);
			drawFilledBox(cr, box, box.getLeft(), value1, box.getRight(), value2);
			cr.fill();
		} 
	}
	override bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable
	{
		if (_direction == Direction.x) {
			left  = log_x_value_of(_value1, logx);
			right = log_x_value_of(_value2, logx);
			return true;
		}
		return false;
	}
	override bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable
	{
		if (_direction == Direction.y) {
			bottom = log_y_value_of(_value1, logy);
			top    = log_y_value_of(_value2, logy);
			return true;
		}
		return false;
	}
	override bool mouseDistance(out double dx, out double dy, double x, double y, bool logx, bool logy, VisualizerContext context) immutable
	{
		auto visu_context = cast(Gate1VisualizerContext)context;
		import std.math, std.algorithm;
		import logscale;
		if (_direction == Direction.x) {
			double value1 = log_x_value_of(_value1, logx, double.init);
			double value2 = log_x_value_of(_value2, logx, double.init);
			if (value1 is double.init || value2 is double.init) {
				return false;
			} else {
				double dx1 = x-value1;
				double dx2 = x-value2;
				if (abs(dx1) < abs(dx2)) {
					dx = dx1;
					if (visu_context.selcted_index != 1) {
						visu_context.selcted_index = 1;
						visu_context.changed = true;
					}
				} else {
					dx = dx2;
					if (visu_context.selcted_index != 2) {
						visu_context.selcted_index = 2;
						visu_context.changed = true;
					}
				}
				if (x > value1 && x < value2){// in between both markers
					import std.stdio;
					double dv = value2-value1;
					dx = dv;
					if (visu_context.selcted_index != 3) {
						visu_context.selcted_index = 3;
						visu_context.changed = true;
					}
					// return true to indicate "weak selection" which means that the selection has low priority
					// over other items that are selected because of proximity
					return true;
				}
			}
		} else {
			double value1 = log_y_value_of(_value1, logy, double.init);
			double value2 = log_y_value_of(_value2, logy, double.init);
			if (value1 is double.init || value2 is double.init) {
				return false;
			} else {
				double dy1 = y-value1;
				double dy2 = y-value2;
				if (abs(dy1) < abs(dy2)) {
					dy = dy1;
					if (visu_context.selcted_index != 1) {
						visu_context.selcted_index = 1;
						visu_context.changed = true;
					}
				} else {
					dy = dy2;
					if (visu_context.selcted_index != 2) {
						visu_context.selcted_index = 2;
						visu_context.changed = true;
					}
				}

				if (y > value1 && y < value2){// in between both markers
					double dv = value2-value1;
					dy = dv;
					if (visu_context.selcted_index != 3) {
						visu_context.selcted_index = 3;
						visu_context.changed = true;  // set this to true whenever we want to trigger a redraw
					}
					// return true to indicate "weak selection" which means that the selection has low priority
					// over other items that are selected because of proximity
					return true;
				}
			}
		}
		return false;
	}

	override void mouseButtonDown(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
		import std.stdio;
	}
	override void mouseDrag(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
		auto visu_context = cast(Gate1VisualizerContext)context;
		double delta1, delta2;
		if (_direction == Direction.x) {
			if (visu_context.selcted_index == 1 || visu_context.selcted_index == 3) {
				delta1 = mouse_action.x_current - mouse_action.x_start;
			}
			if (visu_context.selcted_index == 2 || visu_context.selcted_index == 3) {
				delta2 = mouse_action.x_current - mouse_action.x_start;
			}
		} else {
			if (visu_context.selcted_index == 1 || visu_context.selcted_index == 3) {
				delta1 = mouse_action.y_current - mouse_action.y_start;
			}
			if (visu_context.selcted_index == 2 || visu_context.selcted_index == 3) {
				delta2 = mouse_action.y_current - mouse_action.y_start;
			}
		}
		import std.stdio;

		// create a new item with the updated position
		bool logscale = false;
		if (logx && _direction == Direction.x ||
			logy && _direction == Direction.y) {
			logscale = true;
		} 
		// send an item with the temporary changes
		sessionTid.send(MsgAddItem(mouse_action.itemname, new immutable(Gate1Factory)(_value1, _value2, delta1, delta2, logscale, _colorIdx, _direction)));
		sessionTid.send(MsgEchoRedrawContent(mouse_action.gui_idx), thisTid);

	}
	override void mouseButtonUp(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
		auto visu_context = cast(Gate1VisualizerContext)context;
		import std.stdio, std.math;
		import logscale;
		double delta1 = 0, delta2 = 0;
		if (_direction == Direction.x) {
			if (visu_context.selcted_index == 1 || visu_context.selcted_index == 3) {
				delta1 = mouse_action.x_current - mouse_action.x_start;
			}
			if (visu_context.selcted_index == 2 || visu_context.selcted_index == 3) {
				delta2 = mouse_action.x_current - mouse_action.x_start;
			}
		} else {
			if (visu_context.selcted_index == 1 || visu_context.selcted_index == 3) {
				delta1 = mouse_action.y_current - mouse_action.y_start;
			}
			if (visu_context.selcted_index == 2 || visu_context.selcted_index == 3) {
				delta2 = mouse_action.y_current - mouse_action.y_start;
			}
		}

		if (logx && _direction == Direction.x ||
			logy && _direction == Direction.y) {
			// send an item with the permanent changes
			sessionTid.send(MsgAddItem(mouse_action.itemname, 
										new immutable(Gate1Factory)(_value1*exp(delta1), _value2*exp(delta2), double.init, double.init, true, _colorIdx, _direction)));
		} else {
			sessionTid.send(MsgAddItem(mouse_action.itemname, 
										new immutable(Gate1Factory)(_value1+delta1, _value2+delta2, double.init, double.init, false, _colorIdx, _direction)));
		}
		sessionTid.send(MsgRequestItemVisualizer(mouse_action.itemname, mouse_action.gui_idx), thisTid);
		sessionTid.send(MsgEchoRedrawContent(mouse_action.gui_idx), thisTid);
	}

	override VisualizerContext createContext() {
		//import std.stdio;
		//writeln("Gate1VisualizerContext created\r");
		return new Gate1VisualizerContext;
	}

private:
	double _value1;
	double _value2;
	Direction _direction;

}
