#!/usr/bin/env bash
echo `ls /train`
echo `ls /test`
python /create-submission.py
echo `ls /output`
