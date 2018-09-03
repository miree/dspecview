@safe:
import session;
class IntValue : Item 
{
public:
	this(int v) {
		value = v;
	}
	override immutable(IntValueVisualizer) createVisualizer() 
	{
		return new immutable(IntValueVisualizer);
	}
private:
	int value;
}

immutable class IntValueVisualizer : Visualizer 
{
public:
	override void print(int context) immutable 
	{

	}

	import cairo.Context, cairo.Surface;
	import view;

	override void draw(ref Scoped!Context cr, ViewBox box, bool logy, bool logx, bool logz) immutable
	{

	}

}

