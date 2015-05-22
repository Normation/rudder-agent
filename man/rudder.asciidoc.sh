#!/bin/sh

set -e
BASEDIR="../share/commands"
OUTPUT="rudder.asciidoc"

echo "= rudder(1)
:doctype: manpage

== NAME

rudder - execute commands to control the Rudder configuration management tool.

== SYNOPSIS

*rudder* _component_ [_option_] _command_

*rudder* _component_ help

== DESCRIPTION

A tool to trigger actions or get information about a running rudder-agent,
whether on agent or server. It only targets administration actions, for all
node configuration tasks you can use the rudder-cli tool.

== OPTIONS

*-h*::
  Print command-line syntax and command options.
*-v*::
  Print detailed information.
*-d*::
  Print all available information.

== COMMANDS" > ${OUTPUT}

for role in `ls "${BASEDIR}" | sed 's/\([A-Za-z_]*\)-.*/\1/' | uniq`
do
echo "=== ${role}

commands for rudder ${role}, run with *rudder* *${role}* _command_
" >> ${OUTPUT}

for file in `cd "${BASEDIR}"; find . -type f -name "${role}-*" | sort`
   do
   doc=`sed -ne "/#[ \t]*@description[ \t]*/s/#[ \t]*@description[ \t]*//p" "${BASEDIR}/${file}"`
   man=`sed -ne "/#[ \t]*@man[ \t]*/s/#[ \t]*@man[ \t]*//p" "${BASEDIR}/${file}"`
   name=`echo "${file}" | sed -e "s/\.\/${role}-//"`
echo "*${name}*::
  ${doc}. ${man}
" >> ${OUTPUT}

done
done

echo "== AUTHOR

Normation SAS (contact@normation.com)

== RESOURCES

Main web site: https://rudder-project.org/

Sources of the rudder command-line: https://github.com/Normation/rudder-agent/

== COPYING

Copyright \(C) 2014-2015 Normation SAS." >> ${OUTPUT}
