
struct ViewBox
{
	// the defining numbers for a view box
	double left, right, bottom, top;

	// coefficients for linear transformation
	double a_x, b_x, a_y, b_y;
	// calculate coefficients in order to draw on a canvas that goes from x_offset to left+width in x direction
	//     and from top downto y_offset+height in downwards y direction
	void update_coefficients(int x_offset, int width, int y_offset, int height)
	{
		b_y = height / (bottom - top);
		a_y = y_offset - b_y*top;

		b_x = width / (right - left);
		a_x = x_offset - b_x*left;		
	}

	double transform_box2canvas_x(in double x)
	{
		return a_x + b_x * x;
	}
	double transform_box2canvas_y(in double y)
	{
		return a_y + b_y * y;
	}

	double transform_canvas2box_x(in double x)
	{
		return (x - a_x) / b_x;
	}
	double transform_canvas2box_y(in double y)
	{
		return (y - a_y) / b_y;
	}

	//// this should not be part of this struct
	//// before this makes sense, update_coefficients had to be called
	//void drawLine(ref Scoped!Context cr, double x1, double y1, double x2, double y2)
	//{
	//	double x1_canvas = transform_box2canvas_x(x1);
	//	double y1_canvas = transform_box2canvas_y(y1);
	//	double x2_canvas = transform_box2canvas_x(x2);
	//	double y2_canvas = transform_box2canvas_y(y2);
	//	cr.moveTo(x1_canvas,y1_canvas);		
	//	cr.lineTo(x2_canvas,y2_canvas);
	//}

}