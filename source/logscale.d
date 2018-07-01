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

double log_x_value_of(double x, ViewBox box, bool logx) {
	import std.math;
	if (logx) {
		return (x>0)?log(x):box.getLeft;
	}
	return x;
}

double log_x_value_of(shared double x, bool logx) {
	import std.math;
	if (logx) {
		return (x>0)?log(x):log(0.5);
	}
	return x;
}


