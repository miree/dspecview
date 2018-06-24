
// root interface for all items in the application

synchronized interface Item
{
	string getType(); // a string that is displayed to the user
	string getInfo(); // additional information displayed to the user
}