#!/bin/bash

cd hugo/content/headings
ls | grep "^[^w]" | xargs -n 1 rm -r
cd ../issues
ls | grep "1864-[12345678]*" | xargs rm -r
cd ../terms
ls | grep "^[^w]" | xargs -n 1 rm -r
