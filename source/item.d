
import cairo.Context;
import cairo.Surface;
import view;

interface Item
{
	string getType();

	double getLeft();
	double getRight();
	double getBottom();
	double getTop();
	final double getWidth() { return getRight() - getLeft(); }
	final double getHeight() { return getTop() - getBottom(); }

	void draw(ref Scoped!Context cr, ViewBox box);

	@property ref bool autoScaleX();
	@property ref bool autoScaleY();
}