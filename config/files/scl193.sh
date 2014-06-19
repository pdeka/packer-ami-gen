#!/bin/bash
# Setup PATH, LD_LIBRARY_PATH and MANPATH for ruby-1.9
export PATH=$(dirname `scl enable ruby193 "which ruby"`):$PATH
export LD_LIBRARY_PATH=$(scl enable ruby193 "printenv LD_LIBRARY_PATH"):$LD_LIBRARY_PATH
export MANPATH=$(scl enable ruby193 "printenv MANPATH"):$MANPATH