


import item;

struct SessionRefresh
{
}

synchronized class Session
{
public:
	void addItem(string name, shared Item item)
	{
		_items[name] = item;
	}
	void removeItem(string name)
	{
		_items.remove(name);
	}

	shared(Item)[string] getItems()
	{
		return cast(shared(Item)[string])_items;
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
	shared(Item)[string] _items;
}

