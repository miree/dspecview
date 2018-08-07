
import std.stdio;

public import item;

import cairo.Context;
import cairo.Surface;
import view;




synchronized class Drawable : Item
{
	override string getType()   {
		return "Drawable";
	}
	override string getInfo() {
		return "can be vizualized to user";
	}
	override string getName() {
		return _name;
	}
	override void refresh() {
		writeln("Draw.refresh called()");
	}


	this(string name)
	{
		_name = cast(shared string)name;
	}

	override int getDim() {
		return 0;
	}

	bool needsColorKey() {
		return false;
	}
	double minColorKey() {
		return 0;
	}
	double maxColorKey() {
		return 1;
	}

	double getLeft()	{
		return _left;
	}
	double getRight()	{
		return _right;
	}
	double getBottom()	{
		return _bottom;
	}
	double getTop()	{
		return _top;
	}
	bool getBottomTopInLeftRight(ref double bottom, ref double top, double left, double right, bool logy, bool logx) {
		return false;
	}
	void getLeftRight(ref double left, ref double right, bool logy, bool logx) {
		import logscale;
		left  = log_x_value_of(getLeft(),logx);
		right = log_x_value_of(getRight(),logx);
	}
	final double getWidth() { return getRight() - getLeft(); }
	final double getHeight() { return getTop() - getBottom(); }


	void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz) {}; // show the Drawable on a cairo context


protected:

	shared string _name;

	shared double _left, _right;
	shared double _bottom, _top;
}