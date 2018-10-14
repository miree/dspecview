import session;

class Gate2 : Item
{
public:
	// lrbt = left_right_bottom_top
	this(immutable double[] lrbt, immutable double[] delta_lrbt, bool logx, bool logy, int colorIdx) pure {
		_lrbt = lrbt.dup;
		_delta_lrbt = delta_lrbt.dup;
		_logx = logx;
		_logy = logy;
		_colorIdx  = colorIdx;
		if (getLeft() > getRight()){
			_lrbt[0] = lrbt[1];
			_lrbt[1] = lrbt[0];
			_delta_lrbt[0] = delta_lrbt[1];
			_delta_lrbt[1] = delta_lrbt[0];
		}
		if (getBottom() > getTop()){
			_lrbt[2] = lrbt[3];
			_lrbt[3] = lrbt[2];
			_delta_lrbt[2] = delta_lrbt[3];
			_delta_lrbt[3] = delta_lrbt[2];
		}
	}

	immutable(Visualizer) createVisualizer() {
		return new immutable(Gate2Visualizer)(_lrbt, _colorIdx);
	}

	override string getTypeString() {
		import std.conv;
		return  "2D Gate (" ~ getLeft().to!string ~ "," ~ getRight().to!string ~ ") (" ~ getBottom().to!string ~ "," ~ getTop().to!string ~ ")";
	}

	override int getColorIdx() {
		return _colorIdx;
	}
	override void setColorIdx(int idx) {
		_colorIdx = idx;
	}

	double getLeft() pure {
		if (_delta_lrbt !is null && _delta_lrbt[0] !is double.init) {
			if (_logx) {
				import std.math;
				return _lrbt[0]*exp(_delta_lrbt[0]);
			}
			return _lrbt[0] + _delta_lrbt[0];
		}
		return _lrbt[0];
	}
	double getRight() pure {
		if (_delta_lrbt !is null && _delta_lrbt[1] !is double.init) {
			if (_logx) {
				import std.math;
				return _lrbt[1]*exp(_delta_lrbt[1]);
			}
			return _lrbt[1] + _delta_lrbt[1];
		}
		return _lrbt[1];
	}

	double getBottom() pure {
		if (_delta_lrbt !is null && _delta_lrbt[2] !is double.init) {
			if (_logy) {
				import std.math;
				return _lrbt[2]*exp(_delta_lrbt[2]);
			}
			return _lrbt[2] + _delta_lrbt[2];
		}
		return _lrbt[2];
	}
	double getTop() pure {
		if (_delta_lrbt !is null && _delta_lrbt[3] !is double.init) {
			if (_logy) {
				import std.math;
				return _lrbt[3]*exp(_delta_lrbt[3]);
			}
			return _lrbt[3] + _delta_lrbt[3];
		}
		return _lrbt[3];
	}	

private:
	int       _colorIdx;
	double[]  _lrbt;
	double[]  _delta_lrbt;
	bool      _logx; // is needed if the delta was determined in logscale window
	bool      _logy; // is needed if the delta was determined in logscale window
}

immutable class Gate2Factory : ItemFactory
{
	this(double[] lrbt, double[] delta_lrbt, bool logx, bool logy, int colorIdx) pure {
		_lrbt = lrbt.idup;
		_delta_lrbt = delta_lrbt.idup;
		_logx = logx;
		_logy = logy;
		_colorIdx  = colorIdx;
	}
	override Item getItem() pure {
		return new Gate2(_lrbt, _delta_lrbt, _logx, _logy, _colorIdx );
	}
private:	
	int       _colorIdx;
	double[]    _lrbt;
	double[]    _delta_lrbt;
	bool      _logx; // is needed if the delta was determined in logscale window
	bool      _logy; // is needed if the delta was determined in logscale window
}

class Gate2VisualizerContext : VisualizerContext
{
	int selcted_index;
}

immutable class Gate2Visualizer : BaseVisualizer 
{
public:
	import std.concurrency;
	import cairo.Context, cairo.Surface;
	import view, logscale;

	this(double[] lrbt, int colorIdx) {
		super(colorIdx);
		_lrbt = lrbt.idup;
	}
	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz, ItemMouseAction mouse_action, VisualizerContext context) immutable
	{
		auto visu_context = cast(Gate2VisualizerContext)context;
		import std.stdio;
		immutable double alpha_value=0.3;   // alpha value of gate visualization
										    // 0 is completely transparent, 1 is completely opaque
		//writeln("draw() : visu_context.selcted_index=",visu_context.selcted_index,"\r");
		double linewidth = cr.getLineWidth();
		import logscale, primitives;
		if (logx && (_lrbt[0] < 0 || _lrbt[1] < 0))  {
			return; // TODO: we could do this better ... but later
		}
		if (logy && (_lrbt[2] < 0 || _lrbt[3] < 0))  {
			return; // TODO: we could do this better ... but later
		}
		double left   = log_x_value_of(_lrbt[0], logx);
		double right  = log_x_value_of(_lrbt[1], logx);
		double bottom = log_y_value_of(_lrbt[2], logy);
		double top    = log_y_value_of(_lrbt[3], logy);
		if (mouse_action.relevant && mouse_action.button_down) {
			if (visu_context.selcted_index == 1 || visu_context.selcted_index == 5) {
				left  += mouse_action.x_current - mouse_action.x_start;
			}
			if (visu_context.selcted_index == 2 || visu_context.selcted_index == 5) {
				right  += mouse_action.x_current - mouse_action.x_start;
			}
			if (visu_context.selcted_index == 3 || visu_context.selcted_index == 5) {
				bottom += mouse_action.y_current - mouse_action.y_start;
			}
			if (visu_context.selcted_index == 4 || visu_context.selcted_index == 5) {
				top += mouse_action.y_current - mouse_action.y_start;
			}
		}
		if (mouse_action.relevant && (visu_context.selcted_index == 1 || visu_context.selcted_index == 5)) {
			cr.setLineWidth(linewidth*2);
		} else {
			cr.setLineWidth(linewidth);
		}
		drawVerticalLine(cr, box, left, bottom, top);
		cr.stroke();

		if (mouse_action.relevant && (visu_context.selcted_index == 2 || visu_context.selcted_index == 5)) {
			cr.setLineWidth(linewidth*2);
		} else {
			cr.setLineWidth(linewidth);
		}
		drawVerticalLine(cr, box, right, bottom, top);
		cr.stroke();

		if (mouse_action.relevant && (visu_context.selcted_index == 3 || visu_context.selcted_index == 5)) {
			cr.setLineWidth(linewidth*2);
		} else {
			cr.setLineWidth(linewidth);
		}
		drawHorizontalLine(cr, box, bottom, left, right);
		cr.stroke();

		if (mouse_action.relevant && (visu_context.selcted_index == 4 || visu_context.selcted_index == 5)) {
			cr.setLineWidth(linewidth*2);
		} else {
			cr.setLineWidth(linewidth);
		}
		drawHorizontalLine(cr, box, top, left, right);
		cr.stroke();

		cr.setSourceRgba(1,1,1, alpha_value);
		drawFilledBox(cr, box, left, bottom, right, top);
		cr.fill();
	}
	override bool getLeftRight(out double left, out double right, bool logy, bool logx) immutable
	{
		left  = log_x_value_of(_lrbt[0], logx);
		right = log_x_value_of(_lrbt[1], logx);
		return true;
	}
	override bool getBottomTopInLeftRight(out double bottom, out double top, double left, double right, bool logy, bool logx) immutable
	{
		bottom = log_y_value_of(_lrbt[2], logy);
		top    = log_y_value_of(_lrbt[3], logy);
		return true;
	}
	override bool mouseDistance(ViewBox box, out double dx, out double dy, out double dr, double x, double y, bool logx, bool logy, VisualizerContext context) immutable
	{
		auto visu_context = cast(Gate2VisualizerContext)context;
		import std.math, std.algorithm;
		import logscale;
		double left   = log_x_value_of(_lrbt[0], logx, double.init);
		double right  = log_x_value_of(_lrbt[1], logx, double.init);
		double bottom = log_y_value_of(_lrbt[2], logy, double.init);
		double top    = log_y_value_of(_lrbt[3], logy, double.init);
		if (left is double.init || right is double.init ||
			bottom is double.init || top is double.init) {
			return false;
		} else {
			double dx_left  = (x-left)  * box._b_x;
			double dx_right = (x-right) * box._b_x;
			double dy_bottom = (y-bottom) * box._b_y;
			double dy_top    = (y-top)    * box._b_y;
			import std.stdio;
			if (abs(dx_left) < abs(dx_right) &&
				abs(dx_left) < abs(dy_bottom) &&
				abs(dx_left) < abs(dy_top)) {
				dx = dx_left;
				if (visu_context.selcted_index != 1) {
					visu_context.selcted_index = 1;
					visu_context.changed = true;
				}
			} else if (abs(dx_right) < abs(dy_bottom) &&
					   abs(dx_right) < abs(dy_top)) {
				dx = dx_right;
				if (visu_context.selcted_index != 2) {
					visu_context.selcted_index = 2;
					visu_context.changed = true;
				}
			} else if (abs(dy_bottom) < abs(dy_top)) {
				dy = dy_bottom;
				if (visu_context.selcted_index != 3) {
					visu_context.selcted_index = 3;
					visu_context.changed = true;
				}
			} else {
				dy = dy_top;
				if (visu_context.selcted_index != 4) {
					visu_context.selcted_index = 4;
					visu_context.changed = true;
				}
			}

			if (x > left && x < right &&
			    y > bottom && y < top ){// inside 
				import std.stdio;
				double dvx = right - left;
				double dvy = top - bottom;
				dx = min(dvx,dvy);
				dy = min(dvx,dvy);
				if (visu_context.selcted_index != 5) {
					visu_context.selcted_index = 5;
					visu_context.changed = true;
				}
				// return true to indicate "weak selection" which means that the selection has low priority
				// over other items that are selected because of proximity
				return true;
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
		auto visu_context = cast(Gate2VisualizerContext)context;
		//double delta1, delta2;
		//if (_direction == Direction.x) {
		//	if (visu_context.selcted_index == 1 || visu_context.selcted_index == 3) {
		//		delta1 = mouse_action.x_current - mouse_action.x_start;
		//	}
		//	if (visu_context.selcted_index == 2 || visu_context.selcted_index == 3) {
		//		delta2 = mouse_action.x_current - mouse_action.x_start;
		//	}
		//}
		//import std.stdio;

		//// create a new item with the updated position
		//bool logscale = false;
		//if (logx && _direction == Direction.x ||
		//	logy && _direction == Direction.y) {
		//	logscale = true;
		//} 
		//// send an item with the temporary changes
		//sessionTid.send(MsgAddItem(mouse_action.itemname, new immutable(Gate1Factory)(_value1, _value2, delta1, delta2, logscale, _colorIdx, _direction)));
		//sessionTid.send(MsgEchoRedrawContent(mouse_action.gui_idx), thisTid);
		//double value1=_value1, value2=_value2;
		//import std.math, std.stdio;
		//if (logscale) {
		//	if (delta1 !is double.init) {
		//		value1 *= exp(delta1);
		//	}
		//	if (delta2 !is double.init) {
		//		value2 *= exp(delta2);
		//	}
		//} else {
		//	if (delta1 !is double.init) {
		//		value1 += delta1;
		//	}
		//	if (delta2 !is double.init) {
		//		value2 += delta2;
		//	}
		//}

		//import gui;
		//thisTid.send(MsgAllButMyselfUpdateVisualizer( 
		//		mouse_action.itemname,
		//		mouse_action.gui_idx),
		//		cast(immutable(Visualizer)) new immutable(Gate1Visualizer)(value1, value2, _colorIdx, _direction));

	}
	override void mouseButtonUp(Tid sessionTid, ItemMouseAction mouse_action, bool logx, bool logy, VisualizerContext context) immutable
	{
		auto visu_context = cast(Gate2VisualizerContext)context;
		import std.stdio, std.math;
		import logscale;
		double deltax = 0, deltay = 0;
		deltax = mouse_action.x_current - mouse_action.x_start;
		deltay = mouse_action.y_current - mouse_action.y_start;
		//if (visu_context.selcted_index == 2 || visu_context.selcted_index == 5) {
		//	delta2 = mouse_action.x_current - mouse_action.x_start;
		//}
		double[] rlbt_new;
		double[] delta_new;
		foreach(idx, value; _lrbt) {
			if (visu_context.selcted_index == idx+1 || visu_context.selcted_index == 5) {
				if (idx == 0 || idx == 1) {
					if (logx) {
						rlbt_new ~= value * exp(deltax);
					} else {
						rlbt_new ~= value + deltax;
					}
				} 
				else if (idx == 2 || idx == 3) {
					if (logy) {
						rlbt_new ~= value * exp(deltay);
					} else {
						rlbt_new ~= value + deltay;
					}
				}
			} else {
				rlbt_new ~= value;
			}
			delta_new ~= 0;
		}

		sessionTid.send(MsgAddItem(mouse_action.itemname, 
									new immutable(Gate2Factory)(rlbt_new, delta_new, false, false, _colorIdx)));
		sessionTid.send(MsgRequestItemVisualizer(mouse_action.itemname, mouse_action.gui_idx), thisTid);
		sessionTid.send(MsgEchoRedrawContent(mouse_action.gui_idx), thisTid);
	}

	override VisualizerContext createContext() {
		//import std.stdio;
		//writeln("Gate1VisualizerContext created\r");
		return new Gate2VisualizerContext;
	}

	override bool isInteractive() {
		return true;
	}

private:
	double[]    _lrbt;
}
