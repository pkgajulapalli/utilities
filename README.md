Use following code to keep the files in this repository in appropriate paths.

```bash
# Requires updates
cp .gitconfig ~/.gitconfig

# Requires updates
cp .my_functions.sh ~/.my_functions.sh
cp .vimrc ~/.vimrc
cp vlsub.lua /Applications/VLC.app/Contents/MacOS/share/lua/extensions/vlsub.lua

# Add `source ~/.my_functions.sh` line at the end of `~/.bash_profile` file for it to take effect.
echo "source ~/.my_functions.sh" >> ~/.bash_profile
```
