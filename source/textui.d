
import glib.Thread;

// stanard imports
import std.stdio;
import std.array;


// imports for lib linenoise
import core.stdc.string, core.stdc.stdlib;
import deimos.linenoise;

// local imports
import gui;
import session;
import item;
import hist1;


extern(C) void completion(const char *buf, linenoiseCompletions *lc) {
    if (buf[0] == 'h') {
        linenoiseAddCompletion(lc,"hello");
        linenoiseAddCompletion(lc,"hello there");
    }
}


int run(string[] args, Session session)
{

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
            if (!strncmp(line,"gui",3)) {
            	gui.run(args,session);
            	writeln("gui started ");
            } else if (!strncmp(line,"add",3)) {
            	auto content = sline.split(" ");
            	if (content.length != 2) {
            		writeln("expecting: add name ");
            	} else {
            		session.addItem(content[1], new Hist1(new double[](10), 0, 10));
            	}
            	session.listItems();
			}
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
