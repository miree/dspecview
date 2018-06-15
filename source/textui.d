
import glib.Thread;

// stanard imports
import std.stdio;
import std.array;
import std.algorithm;
import std.conv;

import std.concurrency;

// imports for lib linenoise
import core.stdc.string, core.stdc.stdlib;
import deimos.linenoise;

// local imports
import gui;
import session;
import item;
import hist1;

alias CommandType = void function(string[] args, Session session);
CommandType[string] list_of_commands;

void additem(string[] args, Session session)
{
    writeln("additme called with args: ", args);
}

void threadfunction()
{
    gui.run(null, null);
    writeln("hello from other thread");
}
void startgui(string[] args, Session session)
{
    
    gui.run(args,session);
    writeln("gui started ");
}
void startguithread(string[] args, Session session)
{
    
    Tid tid = spawn(&threadfunction);
    writeln("gui started in new thread");
}

void calculator(string[] args, Session session)
{
    if (args.length != 3) {
        writeln("need 3 arguments, got ", args.length, " : ", args);
    }
    operation: switch(args[1][0]) {
        static foreach(op; "+-*/") {
            mixin("case '" ~ op ~ "': writeln(to!double(args[0]) " ~ op ~ " to!double(args[2])); break operation;");
        }
        default: writeln("unknown operation");    
    }
}
 

extern(C) void completion(const char *buf, linenoiseCompletions *lc) {
    // do the conversion from C nullterminated string to D string in
    // a better (shorter) way.
    string request = cstring2string(buf);
    foreach(command, action; list_of_commands) {
        if (command.canFind(request))
            linenoiseAddCompletion(lc,command.ptr);
    }
}

auto cstring2string(const char *buf)
{
    string result;
    while(*buf) {
        result ~= *buf;
        ++cast(char*)buf;
    }
    return result;
}

int run(string[] args, Session session)
{
    // populate list of commands
    //immutable string[] list_of_commands = ["additem", "gui", "quit"];
    list_of_commands["additem"] = &additem;
    list_of_commands["gui"]     = &startgui;
    list_of_commands["guithread"] = &startguithread;
    list_of_commands["calc"]    = &calculator;


    char *line;
    auto prgname = args[0];

    /* Parse options, with --multiline we enable multi line editing. */
    foreach (idx, arg; args[1 .. $]) {
        if (arg == "--multiline") {
            linenoiseSetMultiLine(1);
            writeln("Multi-line mode enabled.");
        } else if (arg == "--gui") {
        	args.length = 1;
            return gui.run(args,session);
        } else {
            stderr.writefln("Usage: %s [--multiline] [--gui]", prgname);
            return 1;
        }
    }

    /* Set the completion callback. This will be called every time the
     * user uses the <tab> key. */
    linenoiseSetCompletionCallback(&completion);

    /* Load history from file. The history file is just a plain text file
     * where entries are separated by newlines. */
    linenoiseHistoryLoad("history.txt"); /* Load the history at startup */

    /* Now this is the main loop of the typical linenoise-based application.
     * The call to linenoise() will block as long as the user types something
     * and presses enter.
     *
     * The typed string is returned as a malloc() allocated string by
     * linenoise, so the user needs to free() it. */
    while((line = linenoise("dspecview> ")) !is null) {
    	string sline;
    	for(int i = 0; line[i] != '\0'; ++i) sline ~= line[i];
        /* Do something with the string. */
        if (line[0] != '\0' && line[0] != '/') {
            printf("echo: '%s'\n", line);
            linenoiseHistoryAdd(line); /* Add to the history. */
            linenoiseHistorySave("history.txt"); /* Save the history on disk. */
            auto dline = cstring2string(line);
            auto tokens = dline.split(' ');
            if (tokens.length > 0) {
                string[] command_args = null;
                if (tokens.length > 1) {
                    command_args = tokens[1..$];
                }
                list_of_commands[tokens[0]](command_args, session);
            }

            //if (!strncmp(line,"gui",3)) {
            //	gui.run(args,session);
            //	writeln("gui started ");
            //} else if (!strncmp(line,"add",3)) {
            //	auto content = sline.split(" ");
            //	if (content.length != 2) {
            //		writeln("expecting: add name ");
            //	} else {
            //		session.addItem(content[1], new Hist1(new double[](10), 0, 10));
            //	}
            //	session.listItems();
			//}
        } else if (!strncmp(line,"/historylen",11)) {
            /* The "/historylen" command will change the history len. */
            int len = atoi(line+11);
            linenoiseHistorySetMaxLen(len);
        } else if (line[0] == '/') {
            printf("Unreconized command: %s\n", line);
        }
        free(line);
    }
    return 0;

}
