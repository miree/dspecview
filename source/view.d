
struct ViewBox
{
	int _rows = 1, _columns = 1;
	@property getRows()    {return _rows;}
	@property getColumns() {return _columns;}

	// the defining numbers for a view box
	double _left = -1, _right = 1, _bottom = -1, _top = 1;
	double _delta_x = 0, _delta_y = 0; // dynamic while translating the view
	double _scale_x = 1, _scale_y = 1; // dynamic while scaling the view

	double getLeft()  {return _left - _delta_x;}
	double getRight() {return getLeft()+getWidth();}
	double getBottom(){return _bottom - _delta_y;}
	double getTop()   {return getBottom()+getHeight();}

	double getWidth() {return (_right - _left)*_scale_x;}
	double getHeight(){return (_top   - _bottom)*_scale_y;}

	// coefficients for linear transformation
	double _a_x, _b_x, _a_y, _b_y;
	// calculate coefficients for the tile (row,column) in order to draw on a canvas 
	//  with width and height, and if there is a tiling of rows and columns
	// this must be called before using the ViewBox after any of row,column,width,height changed
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
	}

	double transform_box2canvas_x(in double x)
	{
		return _a_x + _b_x * x;
	}
	double transform_box2canvas_y(in double y)
	{
		return _a_y + _b_y * y;
	}

	double transform_canvas2box_x(in double x)
	{
		return (x - _a_x) / _b_x;
	}
	double transform_canvas2box_y(in double y)
	{
		return (y - _a_y) / _b_y;
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
		_scale_x = exp(-scale_x_distance/100.);
		double new_left = scaling.x_start_box - _scale_x*(scaling.x_start_box - _left); 
		_delta_x = _left - new_left; 
		// y scaling
		double scale_y_distance = y_new - scaling.y_start;
		_scale_y = exp(scale_y_distance/100.);
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