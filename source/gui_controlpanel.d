
class ControlPanel 
{	
public:
	this(Tid sessionTid, Gui parentGui)
	{
		_sessionTid = sessionTid;
		_parentGui = parentGui;


		_main_box = new Box(GtkOrientation.VERTICAL,0);	

		auto button_hello = new Button("hello");
		void say_hello(Button button) {
			import std.stdio;
			writeln("hello button_clicked ", button.getLabel(), "\r");
		}
		button_hello.addOnClicked(button => say_hello(button)); 
		_main_box.add(button_hello);

		auto button_refresh = new Button("refresh");
		void f_button_refresh(Button button) {
			refresh();
		}
		button_refresh.addOnClicked(button => f_button_refresh(button)); 
		_main_box.add(button_refresh);

		auto button_open = new Button("open");
		void f_button_open(Button button) {
			import multi_file_chooser;
			string[] result;
			auto child_window = new MultiFileChooser(parentGui.getApplication(), _sessionTid);
		}
		button_open.addOnClicked(button => f_button_open(button)); 
		_main_box.add(button_open);

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





