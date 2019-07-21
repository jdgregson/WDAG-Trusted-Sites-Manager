# WDAG Trusted Sites Manager
This provides a set of PowerShell scripts to easily add and remove sites from
the Windows Defender Application Guard tursted sites lists, based on a flat
configuration file.

## Requirements
### PowerShell
WDAG Trusted Sites Manager was developed in PowerShell version 5. It may run on
older versions, but if you encounter any issues, try upgrading to PowerShell v5.

### PolicyFileEditor
WDAG Trusted Sites Manager requires the PolicyFileEditor module. You can install
it by running the following in an elevated PowerShell session:

    install-module PolicyFileEditor
