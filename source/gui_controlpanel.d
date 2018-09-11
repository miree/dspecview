
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


		//auto b1 = new Button("open hist1"); 
		//b1.addOnClicked(delegate void(Button b) {
		//	import gtk.FileChooserNative;
		//	import gtk.FileChooserDialog;
		//	import std.file;
		//	import std.string;
		//	auto file_chooser = new FileChooserNative(
		//								"open file",
		//								this,
		//								GtkFileChooserAction.OPEN,
		//								"open", "cancel");
		//	//writeln("result of file_chooser.run() = ", 
		//	if (ResponseType.ACCEPT == file_chooser.run()) {
		//		//writeln(getcwd(), ": file_chooser filename: ", , "\r");
		//		auto filename = file_chooser.getFilename().chompPrefix(getcwd()~"/"); 
		//		filename = filename.chompPrefix("/");
		//		//writeln("filename = " , filename, "\r");
		//		synchronized {
		//			import hist1;
		//			auto treeview_name = filename;
		//			_session.addItem(treeview_name, new shared Hist1Visualizer(treeview_name, new shared Hist1Filesource(filename)));
		//			foreach(gui; gui_windows) {
		//				gui.updateSession();
		//			}
		//		}
		//	}
		//});


		auto button_refresh = new Button("refresh");
		void f_button_refresh(Button button) {
			refresh();
		}
		button_refresh.addOnClicked(button => f_button_refresh(button)); 
		_main_box.add(button_refresh);

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





