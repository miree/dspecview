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

		import gtk.Box, gtk.FileChooserWidget, gtk.HeaderBar, gtk.Button;
		auto vbox = new Box(Orientation.VERTICAL,1);	
		auto hbar = new HeaderBar();
		hbar.setTitle ("Chooser Files");
		hbar.setSubtitle ("Select Files and Folders");

		auto chooser = new FileChooserWidget (FileChooserAction.OPEN);
		// Multiple files can be selected:
		chooser.setSelectMultiple(true);

		auto cancel = new Button("Cancel");
		cancel.addOnClicked(button => this.destroy());
		auto open = new Button("Open");
		open.addOnClicked(delegate(button) {
				auto selected = chooser.getFilenames();
				string[] full_filenames = selected.toArray!string;

				foreach(full_filename; full_filenames) {
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
	        			foreach(filename; filenames) {
	        				//writeln(pathname ~ '/' ~ filename,"\r");
							sessionTid.send(MsgAddFileHist1(pathname ~ '/' ~ filename), thisTid);
	        			}					
					} else if (dir_entry.isFile) {
						//writeln(" file!\r");
						auto filename = full_filename.chompPrefix(getcwd()~"/"); 
						//writeln(filename,"\r");
						sessionTid.send(MsgAddFileHist1(filename), thisTid);
					} else {
						writeln(" no file, no dir!?\r");
					}
				}
				this.destroy();
			});

		hbar.packStart(cancel);
		hbar.packEnd(open);
		vbox.add(hbar);
		vbox.add(chooser);

		this.add(vbox);
		showAll();
		show();
	}


}