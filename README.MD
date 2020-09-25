Communications Outside Office Hours
===================================

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0) ![This script was last tested in Nuix 8.8](https://img.shields.io/badge/Script%20Tested%20in%20Nuix-8.8-green.svg)

View the GitHub project [here](https://github.com/Nuix/Communications-Outside-Office-Hours) or download the latest release [here](https://github.com/Nuix/Communications-Outside-Office-Hours/releases).

# Overview

This script analyzes the communication date of items which are a communication (e.g. an email).  You define offices hours by a start and stop time and which days of the week the office is open.  The script analyzes the communication dates and then tags the items with several categories:
- Before Office Hours
- During Office Hours
- After Office Hours
- During the Weekend

# Getting Started

## Setup

Begin by downloading the latest release of this code.  Extract the contents of the archive into your Nuix scripts directory.  In Windows the script directory is likely going to be either of the following:

- `%appdata%\Nuix\Scripts` - User level script directory
- `%programdata%\Nuix\Scripts` - System level script directory

# Settings

- **Office Hours Time Zone**: The time zone the office hours start and stop times are specified in.  Communication date values are converted to this timezone before analysis is performed on them.
- **Office Hours Start**: A 24-hour formatted time (e.g. `05:45` for `5:45 AM`) that defines the beginning of office hours.
- **Office Hours End**: A 24-hour formatted time (e.g. `17:45` for `5:45 PM`) that defines the ending of office hours.
- **Office Days**: Which days of the week are considered days the office is open.  Dates that fall on days of the week which are not checked will be considered weekends.

- **Parent Tag**: Parent tag which all classification tags will be nested under.  Value can be blank.  If blank, classification tags will not be nested under any tag.
- **Before Hours Tag**: Nested tag applied to items found to be *Before Office Hours*.
- **After Hours Tag**: Nested tag applied to items found to be *After Office Hours*.
- **During Hours Tag**: Nested tag applied to items found to be *During Office Hours*.
- **Weekend Tag**: Nested tag applied to items found to be on the Weekend (not on one of the selected **Office Days**).
- **Record Day of Week**: Applies a nested tag to each item with the name of the day of the week the communication date falls on.

# Cloning this Repository

This script relies on code from [Nx](https://github.com/Nuix/Nx) to present a settings dialog and progress dialog.  This JAR file is not included in the repository (although it is included in release downloads).  If you clone this repository, you will also want to obtain a copy of Nx.jar by either:
1. Building it from [the source](https://github.com/Nuix/Nx)
2. Downloading an already built JAR file from the [Nx releases](https://github.com/Nuix/Nx/releases)

Once you have a copy of Nx.jar, make sure to include it in the same directory as the script.

# Icon License

```
Silk icon set 1.3

_________________________________________
Mark James
http://www.famfamfam.com/lab/icons/silk/
_________________________________________

This work is licensed under a
Creative Commons Attribution 2.5 License.
[ http://creativecommons.org/licenses/by/2.5/ ]

This means you may use it for any purpose,
and make any changes you like.
All I ask is that you include a link back
to this page in your credits.

Are you using this icon set? Send me an email
(including a link or picture if available) to
mjames@gmail.com

Any other questions about this icon set please
contact mjames@gmail.com
```

# License

```
Copyright 2020 Nuix

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
