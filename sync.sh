#!/bin/sh
# Sync sources to big4 and rebuild the extension there.
rsync -a --exclude venv --exclude '.venv*' --exclude build --exclude '*.so' ./ big4:fastpybase64/ && ssh big4 'cd ~/fastpybase64 && ./.venv/bin/python setup.py build_ext --inplace --force -q 2>&1 | grep -E "error|warning" ; true'
