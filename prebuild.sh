#!/bin/bash
if [ ! -d "GtkD" ]; then
	echo "cloning GtkD repo"
	git submodule add https://github.com/gtkd-developers/GtkD
	echo "building GtkD"
	cd GtkD
	sed -i 's/"targetType": "library"/"targetType": "dynamicLibrary"/' dub.json
	dub build gtk-d:gtkd
	cd ..
fi


