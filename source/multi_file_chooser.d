import gio.Application : GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;

class MultiFileChooser: ApplicationWindow
{
public:
	import session;
	import std.concurrency;
	this(Application application, Tid sessionTid)
	{
		super(application);

		import gtk.Box, gtk.FileChooserWidget, gtk.HeaderBar, gtk.Button, gtk.Image;
		auto vbox = new Box(Orientation.VERTICAL,1);	
		auto hbar = new HeaderBar();
		hbar.setTitle ("Choose Files or Folders");
		hbar.setSubtitle ("GtkD Spectrum Viever");

		auto chooser = new FileChooserWidget (FileChooserAction.OPEN);
		// Multiple files can be selected:
		chooser.setSelectMultiple(true);

		auto cancel = new Button();//"Cancel");
		cancel.add(new Image(StockID.CANCEL, IconSize.MENU));

		cancel.addOnClicked(button => this.destroy());
		auto open = new Button();//"Open");
		open.add(new Image(StockID.YES, IconSize.MENU));
		open.addOnClicked(delegate(button) {
				auto selected = chooser.getFilenames();
				if (selected !is null) {
					string[] full_filenames = selected.toArray!string;
					import std.algorithm;
					foreach(full_filename; full_filenames.sort()) {
						import std.stdio, std.file, std.string, std.path;
						//writeln("----\r");
						//writeln(full_filename,"\r");
						auto dir_entry = DirEntry(full_filename);
						if (dir_entry.isDir) {
							//writeln(" path!\r");
							auto pathname = full_filename.chompPrefix(getcwd()~"/"); 
							import std.algorithm, std.array;
							auto filenames = std.file.dirEntries(pathname, SpanMode.shallow)
					        					.filter!(a => a.isFile)
		        								.map!(a => baseName(a.name))
		        								.array;
		        			foreach(filename; filenames.sort()) {
		        				//writeln(pathname ~ '/' ~ filename,"\r");
								sessionTid.send(MsgAddFileHist1(pathname ~ '/' ~ filename), thisTid);
		        			}					
						} else if (dir_entry.isFile) {
							//writeln(" file!\r");
							auto filename = full_filename.chompPrefix(getcwd()~"/"); 
							//writeln(filename,"\r");
							sessionTid.send(MsgAddFileHist2(filename), thisTid);
						} else {
							writeln(" no file, no dir!?\r");
						}
					}
				}
				this.destroy();
			});

		hbar.packEnd(cancel);
		hbar.packEnd(open);
		vbox.add(hbar);
		vbox.add(chooser);

		this.add(vbox);
		showAll();
		show();
	}


}