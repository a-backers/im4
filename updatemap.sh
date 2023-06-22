#!/bin/bash

cd /home/adminab/im4

git fetch im4 main
git reset --hard FETCH_HEAD
git clean -df

# Make executable
chmod +x ./updatemap.sh
chmod +x ./im4*

# Make executable APP-map
chmod +x ./main/bin/*.pl
