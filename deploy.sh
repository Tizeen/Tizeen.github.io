#!/usr/bin/env bash

jekyll build
cp -ar imgs/ _site/2018/02/12/
rsync -avzP --delete-after _site/ ubuntu@tencent-vps:/var/www/devopsnotes.net/
