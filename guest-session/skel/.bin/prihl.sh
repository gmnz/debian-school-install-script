#!/bin/bash

#clear

#echo -n "Používateľské meno: "
#read  meno
meno=$(zenity --entry --text="Zadaj používateľské meno") && \
(pcmanfm "smb://$meno@kika/stud" &)

##unset password
##prompt="Heslo: "
##while IFS= read -p "$prompt" -r -s -n 1 char
##do
##    if [[ $char == $'\0' ]]
##    then
##        break
##    fi
##    prompt='*'
##    password+="$char"
##done
#echo
#echo "Username is: $meno Password is: $password"


exit 0
