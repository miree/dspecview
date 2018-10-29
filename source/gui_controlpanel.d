
class ControlPanel 
{	
public:
	this(Tid sessionTid, Gui parentGui)
	{
		_sessionTid = sessionTid;
		_parentGui = parentGui;


		_main_box = new Box(GtkOrientation.VERTICAL,0);	

		_treeview = new ScrolledWindowTreeView(_sessionTid, _parentGui);
		_main_box.add(_treeview);
		_main_box.setChildPacking(_treeview,true,true,0,GtkPackType.START);

		refresh();
	}


	import session;
	void refresh()
	{
		_sessionTid.send(MsgRequestItemList(), thisTid);
	}
	void updateTreeStoreFromSession(MsgItemList itemlist)
	{
		_treeview.updateTreeStoreFromSession(itemlist); // just pass this through
	}
	void updateItemTypeInList(MsgUpdateItem itemtype) {
		_treeview.updateItemTypeInList(itemtype); // just pass this through
	}
	
	void up()
	{
		_treeview.up();
	}
	void down()
	{
		_treeview.down();
	}

	void check_itemname(string itemname) 
	{
		_treeview.check_itemname(itemname);
	}

	alias _main_box this;

private:
	import std.concurrency;
	Tid _sessionTid;

	import gui;
	Gui _parentGui;


	import gui_scrolledwindowtreeview;
	ScrolledWindowTreeView _treeview;

public:
	import gtk.Box, gtk.Button;
	Box _main_box;

}





