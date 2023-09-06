# Configuration file for detect_os
The configuration file used for detect_os is used to define regex patterns
within uname output, and define what identifiers are supported within /etc/os-release.

The default configuration is `./supported_os.yml`, but can be changed using `detect_os -c <PATH TO CONFIGURATION>`

## Example
```yaml
- name: RHEL 
  identifier: rhel
  uname_pattern: \.el[0-9]+
  uname_version_pattern: "[0-9]+"

- name: Ubuntu
  identifier: ubuntu 
  uname_pattern: Ubuntu
```

## Fields
### `name`
The name field is simply to provide a user-readable name for an OS.

### `identifier`
The identifier field is what is printed out when a particular OS is detected.
It is also used for verification when fetching OS IDs from /etc/os-release.

### `uname_pattern`
This is used to define a regular expression pattern within `uname -a` output that
uniquely matches the OS.  This option is required when using `detect_os --uname`.

### `uname_version_pattern`
This is sued to define a regular expression pattern that identifies the version of
the OS from within the output from `uname_pattern`.  If a OS does not define this option,
the OS is simply skipped in the case `detect_os --uname --os-version` is used.
