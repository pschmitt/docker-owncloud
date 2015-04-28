#!/usr/bin/env bash

su www-data -s /bin/sh -c "php occ $@"
