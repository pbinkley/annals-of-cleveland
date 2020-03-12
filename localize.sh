#!/bin/sh
find hugo/public -name \*.html \
| xargs sed -i 's|https://www.wallandbinkley.com/projects/2019/annals-of-cleveland||g' 