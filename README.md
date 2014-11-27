rudder-agent
============

Rudder agent support utility repository.

CLI
---
This repository contains a CLI for rudder.
Here is how it works :

 rudder help
 rudder agent help
 rudder agent &lt;command&gt;
 rudder server help
 rudder server &lt;command&gt; # if you have server support

This cli is made to be expandable, which means that you can add new commands at will.

To add a new command, just drop it into /opt/rudder/share/command and/or make
a new pull request to add it to share/command in this repository.

A command must have the following properties :
- be called agent-&lt;command&gt; or server-&lt;command&gt;
- parameters will not include the 'agent', 'server' or &lt;command&gt; given in the command line
- the executable must contain a string with a single line of the form
  # @description &lt;command description&gt;

New commands should follow these guidelines :
- have as few dependencies as possible on the agent side
- if -h is an option, it must provide help
- if -v is an option, it must make the command verbose
- if -d is an option, it must be debug
