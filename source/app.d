// stanard imports
import std.stdio;


// local imports
import gui;
import textui;
import session;

int main(string[] args)
{
	auto session = new Session;

	return textui.run(args, session);
}

