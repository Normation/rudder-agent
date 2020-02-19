#!/bin/sh
# vim: syntax=python
''':'
# First try to run this script with python, else run with python3
if command -v python >/dev/null 2>/dev/null; then
  exec python  "$0" "$@"
elif command -v python3 >/dev/null 2>/dev/null; then
  exec python3 "$0" "$@"
else
  exec python2 "$0" "$@"
'''
import sys
import json

class Section(object):
# Non optimal, it seems to evaluate 2 times each key, I do not know why.

  def __init__(self, oldJson, newJson):
    self.json = oldJson
    self.newJson = newJson
    self.oldMap = {}
    self.newMap = {}
    self.mapping = {
        'PACKAGE_MANAGER_ALLOW_UNTRUSTED': self.manager_untrusted,
        'PACKAGE_ARCHITECTURE_SPECIFIC': (lambda : ""),
        'PACKAGE_POST_HOOK_COMMAND': (lambda : self.parameter_traduction(['RPM_PACKAGE_POST_HOOK_COMMAND'])),
        'PACKAGE_VERSION_SPECIFIC': (lambda : self.parameter_traduction(['RPM_PACKAGE_VERSION', 'APT_PACKAGE_VERSION'])),
        'PACKAGE_MANAGER_OPTIONS': (lambda : ""),
        'PACKAGE_ARCHITECTURE': (lambda : "default"),
        'PACKAGE_VERSION': self.version_upgrade,
        'PACKAGE_MANAGER': (lambda : "default"),
        'PACKAGE_STATE': self.state_upgrade,
        'PACKAGE_LIST': (lambda : self.parameter_traduction(['RPM_PACKAGE_REDLIST', 'APT_PACKAGE_DEBLIST']))
      }
# Acces to the oldMap via apt or rpm
  def parameter_traduction(self, keyList):
    for iKey in keyList:
      if iKey in self.oldMap:
        return self.oldMap[iKey]
    return ""

# Mapping functions to upgrade parameter values
  def manager_untrusted(self):
    if 'APT_PACKAGE_ALLOW_UNTRUSTED' in self.oldMap:
      return self.oldMap['APT_PACKAGE_ALLOW_UNTRUSTED']
    else:
      return "false"

  def version_upgrade(self):
    if self.parameter_traduction(['RPM_PACKAGE_VERSION_DEFINITION', 'APT_PACKAGE_VERSION_DEFINITION']) == "default":
      return "latest"
    else:
      return self.parameter_traduction(['RPM_PACKAGE_VERSION_DEFINITION', 'APT_PACKAGE_VERSION_DEFINITION'])

  def state_upgrade(self):
    mapping = {'add':'present', 'update':'present', 'delete':'absent'}
    return mapping[self.parameter_traduction(['RPM_PACKAGE_REDACTION', 'APT_PACKAGE_DEBACTION'])]


# function to check parameters compatibility
  def abort_upgrade(self, m):
    sys.stdout.write(m + ", aborting the upgrade")
    sys.exit(1)

  def noop(self, dummy):
    return 0

  def unsupported_cases(self):
    version = self.parameter_traduction(['RPM_PACKAGE_VERSION_DEFINITION', 'APT_PACKAGE_VERSION_DEFINITION'])
    if version== "specific":
      criterion = self.parameter_traduction(['RPM_PACKAGE_VERSION_CRITERION', 'APT_PACKAGE_VERSION_CRITERION'])
      criterionMapping = {
          "==":self.noop,
          "!=":self.abort_upgrade,
          ">=":self.abort_upgrade,
          "<=":self.abort_upgrade,
          ">" :self.abort_upgrade,
          "<" :self.abort_upgrade
          }
      continued = criterionMapping[criterion]("{RPM/APT}_PACKAGE_CRITERION set to %s which is untranslatable"%criterion)
      if not self.parameter_traduction(['RPM_PACKAGE_VERSION', 'APT_PACKAGE_VERSION']):
        self.abort_upgrade("{RPM/APT}_PACKAGE_VERSION was empty but {RPM/APT}_PACKAGE_VERSION_DEFINITION was set to 'specific'")

    if self.parameter_traduction(['RPM_PACKAGE_REDACTION', 'APT_PACKAGE_DEBACTION']) == "update":
      self.abort_upgrade("{RPM\APT}_PACKAGE_REDACTION: update")
    if 'RPM_PACKAGE_POST_HOOK_RUN' in self.oldMap and self.oldMap['RPM_PACKAGE_POST_HOOK_RUN'] == "false" and self.oldMap['RPM_PACKAGE_POST_HOOK_COMMAND'] != "":
      self.abort_upgrade("RPM_PACKAGE_POST_HOOK_RUN unset but a post hook command is set to => '%s'"%self.oldMap['RPM_PACKAGE_POST_HOOK_COMMAND'])

# Loop over the sections to find each parameter value and store it in dstMap
  def findValues(self, json, dstMap):
    for k,v in json.items():
      if isinstance(v, dict):
        self.findValues(v, dstMap)
      elif isinstance(v, list):
        for subV in v:
          self.findValues(subV, dstMap)
      elif 'name' in json and 'value' in json:
        key = json['name'].encode('ascii', 'ignore')
        value = json['value'].encode('ascii', 'ignore')
        dstMap[key] = value

# Loop over the sections and replace the old parameter values by the new ones
  def upgrade(self, json):
    for k,v in json.items():
      if isinstance(v, dict):
        self.upgrade(v)
      elif isinstance(v, list):
        for subV in v:
          self.upgrade(subV)
      elif 'name' in json and 'value' in json:
        key = json['name'].encode('ascii', 'ignore')
        value = json['value'].encode('ascii', 'ignore')

        if key in self.mapping.keys():
          json['value'] = self.mapping[key]()


def main():
    baseJson = json.loads("""{
  "id": "",
  "displayName": "Packages",
  "shortDescription": "",
  "longDescription": "",
  "techniqueName": "packageManagement",
  "techniqueVersion": "1.1",
  "parameters": {
    "section": {
      "name": "sections",
      "sections": [
        {
          "section": {
            "name": "Package",
            "vars": [
              {
                "var": {
                  "name": "PACKAGE_LIST",
                  "value": ""
                }
              },
              {
                "var": {
                  "name": "PACKAGE_STATE",
                  "value": ""
                }
              }
            ],
            "sections": [
              {
                "section": {
                  "name": "Package architecture",
                  "vars": [
                    {
                      "var": {
                        "name": "PACKAGE_ARCHITECTURE",
                        "value": ""
                      }
                    },
                    {
                      "var": {
                        "name": "PACKAGE_ARCHITECTURE_SPECIFIC",
                        "value": ""
                      }
                    }
                  ]
                }
              },
              {
                "section": {
                  "name": "Package manager",
                  "vars": [
                    {
                      "var": {
                        "name": "PACKAGE_MANAGER",
                        "value": ""
                      }
                    },
                    {
                      "var": {
                        "name": "PACKAGE_MANAGER_ALLOW_UNTRUSTED",
                        "value": ""
                      }
                    },
                    {
                      "var": {
                        "name": "PACKAGE_MANAGER_OPTIONS",
                        "value": ""
                      }
                    }
                  ]
                }
              },
              {
                "section": {
                  "name": "Package version",
                  "vars": [
                    {
                      "var": {
                        "name": "PACKAGE_VERSION",
                        "value": ""
                      }
                    },
                    {
                      "var": {
                        "name": "PACKAGE_VERSION_SPECIFIC",
                        "value": ""
                      }
                    }
                  ]
                }
              },
              {
                "section": {
                  "name": "Post-modification script",
                  "vars": [
                    {
                      "var": {
                        "name": "PACKAGE_POST_HOOK_COMMAND",
                        "value": ""
                      }
                    }
                  ]
                }
              }
            ]
          }
        }
      ]
    }
  },
  "priority": 5,
  "enabled": true,
  "system": false,
  "policyMode": "default",
  "tags": []
}
""")
    strdata = ""
    for line in sys.stdin:
      strdata += line

    try:
      data = json.loads(strdata)
      section = Section(data, baseJson['parameters']['section'])
      section.findValues(data, section.oldMap)
      section.findValues(baseJson['parameters']['section'], section.newMap)
      section.unsupported_cases()
      section.upgrade(section.newJson)
      sys.stdout.write( json.dumps(section.newJson['sections'][0], sort_keys=True, indent=4, separators=(',', ': ')))
    # This is mandatory to exlude section without migration
    except KeyError:
      sys.stdout.write("")
    

if __name__ == "__main__":
    main()

