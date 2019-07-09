#!/bin/bash
# (C) 2008 Canonical Ltd.
# Author: Martin Pitt <martin.pitt@ubuntu.com>
# License: GPL v2 or later
# modified by David D Lowe and Thomas Detoux

# Debian 7 support by pixline <pixline@gmail.com>
# It NEEDS /bin/bash, dash won't work (sed issues).
#
# Setup user and temporary home directory for guest session.
# If this succeeds, this script needs to print the username as the last line to
# stdout.

add_account ()
{
  HOME=`mktemp -td guest-XXXXXX`
  USER=`echo $HOME | sed 's/\(.*\)guest/guest/'`

  # if $USER already exists, it must be a locked system account with no existing
  # home directory
  if PWSTAT=`passwd -S "$USER"` 2>/dev/null; then
    if [ "`echo \"$PWSTAT\" | cut -f2 -d\ `" != "L" ]; then
      echo "User account $USER already exists and is not locked"
      exit 1
    fi
    PWENT=`getent passwd "$USER"` || {
      echo "getent passwd $USER failed"
      exit 1
    }
    GUEST_UID=`echo "$PWENT" | cut -f3 -d:`
    if [ "$GUEST_UID" -ge 500 ]; then
      echo "Account $USER is not a system user"
      exit 1
    fi
    HOME=`echo "$PWENT" | cut -f6 -d:`
    if [ "$HOME" != / ] && [ "${HOME#/tmp}" = "$HOME" ] && [ -d "$HOME" ]; then
      echo "Home directory of $USER already exists"
      exit 1
    fi
  else
    # does not exist, so create it
    adduser --force-badname --system --no-create-home --home / --gecos "guest" --group --shell /bin/bash $USER || {
        umount "$HOME"
        rm -rf "$HOME"
        exit 1
    }
  fi

  adduser $USER audio

  # create temporary home directory
  mount -t tmpfs -o mode=700 none "$HOME" || { rm -rf "$HOME"; exit 1; }
  chown $USER:$USER "$HOME"
  gs_skel=/etc/guest-session/skel/
  if [ -d "$gs_skel" ] && [ -n "`find $gs_skel -type f`" ]; then
    cp -rT $gs_skel "$HOME"
  else
    cp -rT /etc/skel/ "$HOME"
  fi
  chown -R $USER:$USER "$HOME"
  usermod -d "$HOME" "$USER"

  #
  # setup session
  #

  # disable screensaver, to avoid locking guest out of itself (no password)
  su $USER <<EOF
  gconftool-2 --set --type bool /desktop/gnome/lockdown/disable_lock_screen True
EOF

  # disable some services that are unnecessary for the guest session
  mkdir --parents "$HOME"/.config/autostart
  cd /etc/xdg/autostart/
  services="jockey-gtk.desktop update-notifier.desktop user-dirs-update-gtk.desktop"
  for service in $services
  do
    if [ -e /etc/xdg/autostart/"$service" ] ; then
        cp "$service" "$HOME"/.config/autostart
        echo "X-GNOME-Autostart-enabled=false" >> "$HOME"/.config/autostart/"$service"
    fi
  done

  # Load restricted session
  #dmrc='[Desktop]\nSession=guest-restricted'
  #/bin/echo -e "$dmrc" > "$HOME"/.dmrc

  chown -R $USER:$USER "$HOME"

  # set possible local guest session preferences
  if [ -f /etc/guest-session/prefs.sh ]; then
      . /etc/guest-session/prefs.sh
  fi

  rm -rf /home/server/public_html/*
  chown -R $USER:$USER /home/server/public_html
  ln -s /home/server/public_html /tmp/$USER/Desktop/server

  mysql -e "drop database guest"
  mysql -e "drop user 'guest'@'localhost'"
  
  mysql -e "CREATE DATABASE guest /*\!40100 DEFAULT CHARACTER SET utf8 */;"
  mysql -e "CREATE USER guest@localhost IDENTIFIED BY 'guest';"
  mysql -e "GRANT ALL PRIVILEGES ON guest.* TO 'guest'@'localhost';"
  mysql -e "FLUSH PRIVILEGES;"

  echo $USER  
}

remove_account ()
{
  USER=$1
  
  PWENT=`getent passwd "$USER"` || {
    echo "Error: invalid user $USER"
    exit 1
  }
  GUID=`echo "$PWENT" | cut -f3 -d:`
  HOME=`echo "$PWENT" | cut -f6 -d:`

  if [ "$GUID" -ge 500 ]; then
    echo "Error: user $USER is not a system user."
    exit 1
  fi

  if [ "${HOME}" = "${HOME#/tmp/}" ]; then
    echo "Error: home directory $HOME is not in /tmp/."
    exit 1
  fi

  # kill all remaining processes
  while ps h -u "$USER" >/dev/null; do 
    killall -9 -u "$USER" || true
    sleep 0.2; 
  done

  umount "$HOME" || umount -l "$HOME" || true
  rm -rf "$HOME"

  # remove leftovers in /tmp
  find /tmp -mindepth 1 -maxdepth 1 -uid "$GUID" -print0 | xargs -0 rm -rf || true

  deluser --system "$USER"
}

case "$1" in
  add)
    add_account
    ;;
  remove)
    if [ -z $2 ] ; then
      echo "Usage: $0 remove [account]"
      exit 1
    fi
    remove_account $2
    ;;
  *)
    echo "Usage: $0 add|remove"
    exit 1
esac
