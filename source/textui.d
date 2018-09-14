// globally store the Tid for the session thread
Tid sessionTid;

alias CommandType = void function(immutable string[] args);
CommandType[string] list_of_commands;

void populate_list_of_commands()
{
	list_of_commands["calc"]        = &calculator;
	list_of_commands["hi"]          = &sayHiToSession;
	list_of_commands["stop"]        = &stopSession;
	list_of_commands["run"]         = &runSession;
	//list_of_commands["addint"]      = &addIntValue;
	list_of_commands["ls"]          = &listItems;
	list_of_commands["filehist1"]   = &addFileHist1;
	//list_of_commands["visualizer"]  = &getItemVisualizer;
	list_of_commands["gui"]         = &runGui;
	list_of_commands["rm"]          = &rmItem;
	list_of_commands["!ls"]         = &listDir;
}

/////////////////////////////////////////////////////////////
// It follows a list of functions, each function represents
// one command that can be run as terminal command.
// They are appended to the 'list_of_commands array' further 
// down in this module
void calculator(immutable string[] args)
{
	import std.stdio, std.conv;
	if (args.length != 3) {
		writeln("need 3 arguments, got ", args.length, " : ", args);
		return;
	}
	operation: switch(args[1][0]) {
		static foreach(op; "+-*/") {
			mixin("case '" ~ op ~ "': writeln(to!double(args[0]) " ~ op ~ " to!double(args[2])); break operation;");
		}
		default: writeln("unknown operation");    
	}
}

void listDir(immutable string[] args) 
{
	import std.stdio;
	if (args.length != 1) {
		writeln("need 1 argument, got ", args.length, " : ", args);
		return;
	}
	string pathname = args[0];
    import std.algorithm;
    import std.array;
    import std.file;
    import std.path;

    auto files = std.file.dirEntries(pathname, SpanMode.shallow)
        .filter!(a => a.isFile)
        .map!(a => baseName(a.name))
        .array;

    foreach(file; files) {
    	writeln(file);
    }
}

void sayHiToSession(immutable string[] args)
{
	import std.stdio, std.concurrency;
	import session;
	if (args.length != 1) {
		writeln("need 1 argument, got", args.length, " : ", args);
		return;
	}
	sessionTid.send(MsgSayHi(args[0]), thisTid);
	writeln(receiveOnly!string);
}

// stop the session main loop
void stopSession(immutable string[] args)
{
	import std.stdio, std.concurrency;
	import session;
	sessionTid.send(MsgStop(), thisTid);
	writeln(receiveOnly!string);
}

// (re-)run the session main loop
void runSession(immutable string[] args)
{
	import std.stdio, std.concurrency;
	import session;
	sessionTid.send(MsgRun(), thisTid);
	writeln(receiveOnly!string);
}

void listItems(immutable string[] args) 
{
	import std.concurrency, std.array, std.algorithm;
	import session;
	// ask session to send us the itemlist
	sessionTid.send(MsgRequestItemList(), thisTid);

	// block until we got the response
	auto itemlist = receiveOnly!MsgItemList;
	import std.stdio;
	foreach(nametype; itemlist.nametype.split('|').array.sort) {
		auto itemname = nametype.split('$')[0];
		auto itemtype = nametype.split('$')[1];
		writeln(itemname, " : ", itemtype);
	}
}

void rmItem(immutable string[] args)
{
	import std.concurrency, std.array, std.algorithm, std.stdio;
	import session;
	if (args.length < 1) {
		writeln("expecting one argument: <itemname> <itemname> ...  , got ", args.length , "arguments: ", args);
		return;
	}
	// ask session to remove this item
	sessionTid.send(MsgRemoveItem(args[0]), thisTid);
}

void addFileHist1(immutable string[] args)
{
	import std.stdio, std.concurrency, std.array, std.algorithm;
	import session;

	if (args.length != 1) {
		writeln("expecting one argument: <filename> , got ", args.length , "arguments: ", args);
		return;
	}

	sessionTid.send(MsgAddFileHist1(args[0]), thisTid);
}

Tid guiTid;
bool guiRunning = false;
void runGui(immutable string[] args)
{
	import gui, session;
	//gui.run(args, sessionTid);
	guiTid = gui.startguithread(args, sessionTid);
	guiRunning = true;

	// tell the session, that a gui thread was started;
	//sessionTid.send(MsgGuiStarted(), guiTid);
}

//////////////////////////////////////////////////
// Using the linenoise library for user friendly 
// command line interface

// imports for lib linenoise
import deimos.linenoise;

extern(C) void completion(const char *buf, linenoiseCompletions *lc) {
	import std.algorithm, core.stdc.string, core.stdc.stdlib;
	// see if we find this in the list of commands
	string request = cstring2string(buf);
	foreach(command, action; list_of_commands) {
		if (command.startsWith(request))
			linenoiseAddCompletion(lc,(command ~ '\0').ptr);
	}
	// see if we find request in the list of items
	//  but only if already a command was entered as first token
	import std.array, std.algorithm;
	auto request_tokens = request.split(' ');
	if (request_tokens.length > 1) { 
		// ... first get the itemlist
		import session;
		sessionTid.send(MsgRequestItemList(), thisTid);
		// block until we got the response
		auto items = receiveOnly!MsgItemList;
		foreach(nametype; items.nametype.split('|')) {
			auto itemname = nametype.split('$')[0];
			auto an_item = itemname ~ '\0';
			if (an_item.startsWith(request_tokens[$-1])) {
				string suggestion;
				foreach(token; request_tokens[0..$-1]) {
					suggestion ~= token ~ ' ';
				}
				suggestion ~= an_item;
				linenoiseAddCompletion(lc, suggestion.ptr);
			}
		}
	}

/+	// see if we find request in the current directory in the file system
	//  but only if already a command was entered as first token
	import std.stdio, std.array, std.algorithm;
	if (request_tokens.length > 1) { 
		// first get the filelist
		string pathname = "./";// ~ request_tokens[$-1];
		writeln("pathname is ", pathname);
	    import std.algorithm;
	    import std.array;
	    import std.file;
	    import std.path;

	    auto files = std.file.dirEntries(pathname, SpanMode.shallow)
//	        .filter!(a => a.isFile)
	        .map!(a => baseName(a.name))
	        .array;

		// ... first get the itemlist
		import session;
		sessionTid.send(MsgRequestItemList(), thisTid);
		// block until we got the response
		auto items = receiveOnly!MsgItemList;
		foreach(item; files) {
			auto an_item = item ~ '\0';
			if (an_item.startsWith(request_tokens[$-1])) {
				string suggestion;
				foreach(token; request_tokens[0..$-1]) {
					suggestion ~= token ~ ' ';
				}
				suggestion ~= an_item;
				linenoiseAddCompletion(lc, suggestion.ptr);
			}
		}
	}
+/
}

auto cstring2string(const char *buf) {
	string result;
	while(*buf) {
		result ~= *buf;
		++cast(char*)buf;
	}
	return result;
}



import std.concurrency;
int run(immutable string[] args, Tid sesTid) 
{
	import std.stdio;
	sessionTid = sesTid;

	populate_list_of_commands();

	char *line;
	auto prgname = args[0];

	/* Parse options, with --multiline we enable multi line editing. */
	foreach (idx, arg; args[1 .. $]) {
		if (arg == "--multiline") {
			linenoiseSetMultiLine(1);
			writeln("Multi-line mode enabled.");
		} else {
			stderr.writefln("Usage: %s [--multiline] [--gui]", prgname);
			return 1;
		}
	}

	// completion callback 
	linenoiseSetCompletionCallback(&completion);

	// command history file
	linenoiseHistoryLoad("history.txt");

	// linenoise main loop, line is created by malloc and has to be freed with free() 
	while((line = linenoise("dspecview> ")) !is null) {
		import std.array, core.stdc.string, core.stdc.stdlib;
		string sline;
		for(int i = 0; line[i] != '\0'; ++i) sline ~= line[i];
		// Do something with the string. 
		if (line[0] != '\0' && line[0] != '/') {
			linenoiseHistoryAdd(line); // Add to the history. 
			linenoiseHistorySave("history.txt"); // Save the history on disk. 
			auto dline = cstring2string(line);
			auto tokens = dline.split(' ');
			if (tokens.length > 0) {
				// tokens[0]    is the command name
				// tokens[1..$] are the optional args
				string[] command_args = null;
				if (tokens.length > 1) {
					command_args = tokens[1..$];
				}
				CommandType *command = (tokens[0] in list_of_commands);
				if (command) {
					(*command)(cast(immutable string[])command_args);
				} else {
					writeln("unknown command ", tokens[0]);
				}
			}

		} else if (!strncmp(line,"/historylen",11)) {
			// The "/historylen" command will change the history len. 
			int len = atoi(line+11);
			linenoiseHistorySetMaxLen(len);
		} else if (line[0] == '/') {
			printf("Unreconized command: %s\n", line);
		}
		free(line);
	}
	return 0;

}
