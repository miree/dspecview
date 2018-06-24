


import item;


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
	shared(Item) getItem(string name)
	{
		return cast(shared(Item))_items[name];
	}

	void listItems()
	{
		import std.array, std.algorithm;
		foreach(name; getItems().byKey().array().sort()) {
			import std.stdio;
			writeln('/',name);
		}
	}


private:
	shared(Item)[string] _items;
}

