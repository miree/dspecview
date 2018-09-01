


import item;
import drawable;


synchronized class Session
{
public:
	void addItem(string name, shared Item item)
	{
		import std.stdio;
		writeln("Session.addItem ", name, "\r");
		_items[name] = item;
	}
	void removeItem(string name)
	{
		_items.remove(name);
	}

	//shared(Item)[string] getItems()
	//{
	//	return cast(shared(Item)[string])_items;
	//}
	string[] getItemList() {
		import std.array, std.algorithm;
		//auto item_list = (cast(shared(Item)[string])_items).byKey.array.sort.array;
		string[] item_list;
		foreach(key, value; _items) { item_list ~= key; }
		return item_list;
	}
	shared(Item) getItem(string name)
	{
		shared(Item*) item = (name in _items);
		if (item != null) {
			return *item;
		}
		return null;
	}
	shared(Drawable) getDrawable(string name)
	{
		shared(Item) item = getItem(name);
		if (item !is null) {
			shared(Drawable) drawable = cast(shared(Drawable))(item);
			return drawable;
		}
		return null;
	}

	void listItems()
	{
		import std.array, std.algorithm;
		foreach(name; getItemList) {
			import std.stdio;
			writeln('/',name);
		}
	}


private:
	Item[string] _items;
}

