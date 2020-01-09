#!/usr/bin/env bash
echo `ls /train`
echo `ls /test`
/usr/local/bin/python /create-submission.py
echo `ls /output`
