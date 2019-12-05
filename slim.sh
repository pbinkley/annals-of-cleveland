#!/bin/bash

cd hugo/content/headings
ls | grep "^[^w]" | xargs -n 1 rm
cd ../issues
ls | grep "1864-[12345678]*" | xargs rm
cd ../terms
ls | grep "^[^w]" | xargs -n 1 rm
