#!/bin/bash

if [ "$1" = "perl" -o "$1" = "perldoc" ]; then
    PERL="$1"
else
    PERL="perl"
fi
PERL5LIB="./lib:./extlib:$PERL5LIB"
$PERL $*
