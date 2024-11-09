#!/bin/bash

# init.sh
#
# Initializes the current shell with the project environment variables and
# utility functions.

source "$(realpath "$(dirname "${BASH_SOURCE[0]}")")/common.sh"
housekeeping

# -------------------------- HEADER -------------------------------------------

# -------------------------- PRECONDITIONS ------------------------------------

# -------------------------- BANNER -------------------------------------------

# -------------------------- PREAMBLE -----------------------------------------

# -------------------------- RECONNAISSANCE -----------------------------------

# -------------------------- EXECUTION ----------------------------------------

# -------------------------- POSTCONDITIONS -----------------------------------

printinfo "Shell has been initialized with project vars and utilities."
printwarn "All output is being logged.  Exit shell when task is complete."

trap "printinfo \"Closing project shell...\"" EXIT
