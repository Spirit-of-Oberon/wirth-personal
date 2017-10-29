#!/bin/sh 
cd www.inf.ethz.ch

git pull

cd ..

wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/536.5 (KHTML, like Gecko) Chrome/19.0.1084.9 Safari/536.5" -r -k -l 7 -p -E -np 'https://www.inf.ethz.ch/personal/wirth/'

cd www.inf.ethz.ch 

git commit -a -m "upd"

git push