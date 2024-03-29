# DebugLightmapProbes for Godot

When a dynamic object is inside a Godot lightmap, it gets its indirect lighting
from an interpolation of four probes. This plugin visualizes which four are
used for any given position in a scene.

![Screenshot](https://github.com/permelin/debug-lightmap-probes/assets/36154/9ebb7d78-1678-4300-b3b7-858e62be6c6b)

I created this tool to make my life easier when I was hunting down some issues
in the engine. But I have found that it is also valuable when manually placing
probes in my projects. Which four probes that are chosen by Godot is very
unintuitive and the tool helps you learn how to best place probes and to verify
that your placement is good.

## How to use

* Drop the files into a folder under `res://addons`.
* Enable the plugin in the project settings.
* There is now a new node type called `DebugLightmapProbes` that you can add to
    your scene.
* Move the node around in the editor. See the screenshot above for what it
    looks like in action.

## Please note

* The tool shows the position of all probes, but they are always
white. It does not show the actual colors that come from the probes.

* When you move or add probes and bake the lightmap, the tool will not update
automatically. It can't, because the lightmap resource is currently not
emitting the `changed` signal as it should. So you need to reload the scene to
see the changes.

## Sweeping the scene

There is an option to sweep an entire scene and look for positions where
the engine doesn't use the correct probes. This feature is only useful if you
are debugging the engine.

