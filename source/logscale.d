@safe:

import view;

double log_color_value_of(double color, bool logcolor) {
	import std.math;
	if (logcolor) {
		return (color>0)?log(color):0; // in color space, 0 is mapped to the "not filled" color
	}
	return color;
}
double log_z_value_of(double z, bool logz) {
	import std.math;
	if (logz) {
		return (z>0)?log(z):0; // in z space, 0 is mapped to the "not filled" color
	}
	return z;
}

double log_y_value_of(double y, ViewBox box, bool logy) {
	import std.math;
	if (logy) {
		return (y>0)?log(y):box.getBottom();
	}
	return y;
}

double log_y_value_of(double y, bool logy, double default_zero = 0.5) {
	import std.math;
	if (logy) {
		return (y>0)?log(y):log(default_zero);
	}
	return y;
}

double log_x_value_of(double x, ViewBox box, bool logx) {
	import std.math;
	if (logx) {
		return (x>0)?log(x):box.getLeft();
	}
	return x;
}

double log_x_value_of(double x, bool logx, double default_zero = 0.5) {
	import std.math;
	if (logx) {
		return (x>0)?log(x):log(default_zero);
	}
	return x;
}


