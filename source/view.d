
struct ViewBox
{
	int _rows = 1, _columns = 1;
	@property getRows()    {return _rows;}
	@property getColumns() {return _columns;}

	// the defining numbers for a view box
	double _left = -1, _right = 1, _bottom = -1, _top = 1;
	double _delta_x = 0, _delta_y = 0; // dynamic while translating the view
	double _scale_x = 0, _scale_y = 0; // dynamic while scaling the view

	double getLeft()  {return _left - _delta_x;}
	double getRight() {return _right- _delta_x;}
	double getBottom(){return _bottom - _delta_y;}
	double getTop()   {return _top    - _delta_y;}

	double getWidth() {return _right - _left;}
	double getHeight(){return _bottom- _top;}

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
		_b_y = canvas_height / getHeight();
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

	// manage transformation state
	struct TransformationInfo
	{
		double x_start, y_start;
		bool active = false;
	}
	TransformationInfo scaling, translating;

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
	}

	void scale_ongoing(double x_new, double y_new)
	{
		_delta_x = (x_new - translating.x_start)/_b_x;
		_delta_y = (y_new - translating.y_start)/_b_y;
	}
	void scale_finish(double x_new, double y_new)
	{
		_left   -= _delta_x;
		_right  -= _delta_x;
		_bottom -= _delta_y;
		_top    -= _delta_y;
		_delta_x = 0;
		_delta_y = 0;
	}


}