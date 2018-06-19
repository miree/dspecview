


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
		import std.array, std.algorithm;
		foreach(name; getItems().byKey().array().sort()) {
			import std.stdio;
			writeln(name);
		}
	}


private:
	Item[string] _items;
}

