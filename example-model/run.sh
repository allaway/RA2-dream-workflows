#!/usr/bin/env bash
echo `ls /train`
echo `ls /test`
python3 /create-submission.py