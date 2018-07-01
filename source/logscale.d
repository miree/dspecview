import view;

double log_y_value_of(double y, ViewBox box, bool logy) {
	import std.math;
	if (logy) {
		return (y>0)?log(y):box.getBottom;
	}
	return y;
}

double log_y_value_of(shared double y, bool logy) {
	import std.math;
	if (logy) {
		return (y>0)?log(y):log(0.5);
	}
	return y;
}