rudder-agent
============

Rudder agent support utility repository.

CLI
---
This repository contains a CLI for rudder.
Here is how it works :

    rudder help
    rudder agent help
    rudder agent <command>
    rudder server help
    rudder server <command> # if you have server support

This cli is made to be expandable, which means that you can add new commands at will.

To add a new command, just drop it into `/opt/rudder/share/command` and/or make
a new pull request to add it to share/command in this repository.

A command must have the following properties :
- be called agent-<command> or server-<command>
- parameters will not include the 'agent', 'server' or <command> given in the command line
- the executable must contain a string with a single line of the form:


    # @description <brief command description>

- the executable may also contain a single or multi-line string of the form:


    # @man <detailed command description>

New commands should follow these guidelines :
- have as few dependencies as possible on the agent side
- if -h is an option, it must provide help
- if -v is an option, it must make the command verbose
- if -d is an option, it must be debug

Build man pages
---------------

In order to build the man pages, you will need:
- [asciidoc](http://www.methods.co.nz/asciidoc/) for man pages: probably packaged by your distribution
- [asciidoctor](http://www.asciidoctor.org) for the HTML output: `gem install asciidoctor`

Then run `make` in the man folder. It will generate `rudder.1` and `rudder.html`.
