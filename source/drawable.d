
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
	bool getBottomTopInLeftRight(ref double bottom, ref double top, in double left, in double right, bool logy) {
			return false;
	}
	final double getWidth() { return getRight() - getLeft(); }
	final double getHeight() { return getTop() - getBottom(); }


	void draw(ref Scoped!Context cr, ViewBox box, bool logy) {}; // show the Drawable on a cairo context


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