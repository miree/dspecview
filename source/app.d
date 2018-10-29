void main(immutable string[] args)
{
    ////////////////////////////////////////////
	// the session has its own event loop 
	// and is running in its own thread
	import std.concurrency;
	import session;

    auto sessionTid = spawn(&runSession);

    ////////////////////////////////////////////
    // lets use the terminal/text user interface
    // as the default entry point after program
    // startup
    import textui;

    auto result = textui.run(args, sessionTid);
}
