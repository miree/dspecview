
import std.stdio;

import item;

class Session
{
public:
	void addItem(string name, Item item)
	{
		_items[name] = item;
	}

	Item[string] getItems()
	{
		return _items;
	}

	void listItems()
	{
		foreach(name, item; _items)
		{
			writeln(name);
		}
	}


private:
	Item[string] _items;
}

