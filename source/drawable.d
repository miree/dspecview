
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
	void getBottomTopInLeftRight(out double bottom, out double top, in double left, in double right) {
		bottom = _bottom;
		top    = _top;
	}
	final double getWidth() { return getRight() - getLeft(); }
	final double getHeight() { return getTop() - getBottom(); }


	void draw(ref Scoped!Context cr, ViewBox box) {}; // show the Drawable on a cairo context


	void setAutoScaleX(bool scale) {
		_autoScaleX = scale;
	}
	void setAutoScaleY(bool scale) {
		_autoScaleY = scale;
	}

	@property bool autoScaleX() {
		return _autoScaleX;
	}
	@property bool autoScaleY() {
		return _autoScaleY;
	}

protected:

	shared string _name;

	shared double _left, _right;
	shared double _bottom, _top;

	bool _autoScaleX = false;
	bool _autoScaleY = false;
}