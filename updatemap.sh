#!/bin/bash

git fetch im4 main
git reset --hard FETCH_HEAD
git clean -df
