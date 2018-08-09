
struct ViewBox
{
	int _rows = 1, _columns = 1;
	@property getRows()    {return _rows;}
	@property getColumns() {return _columns;}

	// the defining numbers for a view box
	double _left = -1, _right = 1, _bottom = -1, _top = 1, _zmin = -1, _zmax = 1;
	double _delta_x = 0, _delta_y = 0, _delta_z = 0; // dynamic while translating the view
	double _scale_x = 1, _scale_y = 1, _scale_z = 1; // dynamic while scaling the view
	double _minimum_width  = 1e-3;
	double _maximum_width  = 1e10;
	double _minimum_height = 1e-3;
	double _maximum_height = 1e10;
	double _minimum_zrange = 1e-3;
	double _maximum_zrange = 1e10;

	void setWidthMinMax(double min, double max) {
		_minimum_width = min;
		_maximum_width = max;
	}
	void setHeightMinMax(double min, double max) {
		_minimum_height = min;
		_maximum_height = max;
	}
	void setZrangeMinMax(double min, double max) {
		_minimum_zrange = min;
		_maximum_zrange = max;
	}

	// the following function to determine the box dimensions are correct
	// at all instances, even when translation/scaling is in progress
	double getLeft()  {return _left - _delta_x;}
	double getRight() {return getLeft()+getWidth();}
	double getBottom(){return _bottom - _delta_y;}
	double getTop()   {return getBottom()+getHeight();}
	double getZmin()  {return _zmin - _delta_z;}
	double getZmax()  {return getZmin()+getZrange();}

	double getWidth() {return (_right - _left)*_scale_x;}
	double getHeight(){return (_top   - _bottom)*_scale_y;}
	double getZrange(){return (_zmax  - _zmin)*_scale_z;}

	void setZminZmax(double zmin, double zmax) {
		_zmin = zmin;
		_zmax = zmax;
		// this freezes all movements and scaling actions in z direction
		_scale_z = 1;
		_delta_z = 0;
	}
	void setBottomTop(double bottom, double top) {
		_bottom = bottom;
		_top    = top;
		// this freezes all movements and scaling actions in y direction
		_scale_y = 1;
		_delta_y = 0;
	}
	void setLeftRight(double left, double right) {
		_left  = left;
		_right = right;
		// this freezes all movements and scaling actions in x direction
		_scale_x = 1;
		_delta_x = 0;
	}

	// coefficients for linear transformation
	double _a_x, _b_x, _a_y, _b_y, _a_z, _b_z;
	// calculate coefficients for the tile (row,column) in order to draw on a canvas 
	//  with width and height, and if there is a tiling of rows and columns
	// this must be called before using the ViewBox after any of row,column,width,height change
	void update_coefficients(int row, int column, int width, int height)
	{
		// canvas properties
		double x_offset = column * width  / _columns;
		double y_offset = row    * height / _rows ;
		double canvas_width  = width  / _columns;
		double canvas_height = height / _rows;

		// calculate coefficients for linear transformation
		_b_y = - canvas_height / getHeight();
		_a_y = y_offset - _b_y*getTop();

		_b_x = canvas_width / getWidth();
		_a_x = x_offset - _b_x*getLeft();

		_b_z = 1.0 / getZrange();
		_a_z = - _b_x*getZmin();
	}
	double get_pixel_width()
	{
		return 1.0/_b_x;
	}
	double get_pixel_height()
	{
		return -1.0/_b_y;
	}

	double transform_box2canvas_x(in double x)
	{
		return _a_x + _b_x * x;
	}
	double transform_box2canvas_y(in double y)
	{
		return _a_y + _b_y * y;
	}
	double transform_box2canvas_z(in double z)
	{
		import std.stdio;
		//write("zin=",z,  " -> ");
		double result = _a_z + _b_z * z;
		//writeln("zout=",result,  " ");
		return result;
	}

	double transform_canvas2box_x(in double x)
	{
		return (x - _a_x) / _b_x;
	}
	double transform_canvas2box_y(in double y)
	{
		return (y - _a_y) / _b_y;
	}
	double transform_canvas2box_z(in double z)
	{
		return (z - _a_z) / _b_z;
	}

	// takes into account the tiling to reduce the x position to the value inside the first tile
	double reduce_canvas_x(in double x, int width)
	{
		int column_width = width/_columns;
		int column = cast(int)x / column_width;
		return x-column*column_width;
	}
	// takes into account the tiling to reduce the y position to the value inside the first tile
	double reduce_canvas_y(in double y, int height)
	{
		int row_height = height/_rows;
		int row = cast(int)y / row_height;
		return y-row*row_height;
	}

	// manage transformation state
	struct TransformationInfo
	{
		double x_start, y_start;
		double x_start_box, y_start_box;
		bool active = false;
	}
	TransformationInfo scaling, translating;

	void translate_one_step(double x_start, double y_start, double x_step, double y_step)
	{
		translate_start(x_start, y_start);
		translate_ongoing(x_start+x_step, y_start+y_step);
		translate_finish(x_start+x_step, y_start+y_step);
	}
	void translate_start(double x_start, double y_start)
	{
		translating.x_start = x_start;
		translating.y_start = y_start;
		translating.active = true;
	}
	void translate_ongoing(double x_new, double y_new)
	{
		_delta_x = (x_new - translating.x_start)/_b_x;
		_delta_y = (y_new - translating.y_start)/_b_y;
	}
	void translate_finish(double x_new, double y_new)
	{
		_left   -= _delta_x;
		_right  -= _delta_x;
		_bottom -= _delta_y;
		_top    -= _delta_y;
		_delta_x = 0;
		_delta_y = 0;
		translating.active = false;
	}

	void scale_one_step(double x_start, double y_start, int width, int height, double x_step, double y_step)
	{
		scale_start(x_start, y_start, width, height);
		scale_ongoing(x_start+x_step, y_start-y_step);
		scale_finish(x_start+x_step, y_start-y_step);
	}
	void scale_start(double x_start, double y_start, int width, int height)
	{
		scaling.x_start = x_start;
		scaling.y_start = y_start;

		update_coefficients(0, 0, width, height);
		scaling.x_start_box = transform_canvas2box_x(reduce_canvas_x(x_start, width));
		scaling.y_start_box = transform_canvas2box_y(reduce_canvas_y(y_start, height));
		scaling.active = true;
	}
	void scale_ongoing(double x_new, double y_new)
	{
		import std.math;
		// x scaling
		double scale_x_distance = x_new - scaling.x_start;
		// limit the x-scaling
		_scale_x = exp(-scale_x_distance/100.);
		if (getWidth < _minimum_width) _scale_x = _minimum_width/(_right-_left);
		if (getWidth > _maximum_width) _scale_x = _maximum_width/(_right-_left);
		double new_left = scaling.x_start_box - _scale_x*(scaling.x_start_box - _left); 
		_delta_x = _left - new_left; 
		// y scaling
		double scale_y_distance = y_new - scaling.y_start;
		_scale_y = exp(scale_y_distance/100.);
		// limit the y-scaling
		if (getHeight < _minimum_height) _scale_y = _minimum_height/(_top-_bottom);
		if (getHeight > _maximum_height) _scale_y = _maximum_height/(_top-_bottom);
		double new_bottom = scaling.y_start_box - _scale_y*(scaling.y_start_box - _bottom); 
		_delta_y = _bottom - new_bottom; 
	}
	void scale_finish(double x_new, double y_new)
	{
		double width = getWidth();
		_left   -= _delta_x;
		_right   = _left + width;
		double height = getHeight();
		_bottom -= _delta_y;
		_top     = _bottom + height;
		_scale_x = 1;
		_scale_y = 1; 
		_delta_x = 0;
		_delta_y = 0;
		scaling.active = false;
	}


}