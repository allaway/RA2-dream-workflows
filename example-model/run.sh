#!/usr/bin/env bash
echo `ls /train`
echo `ls /test`
/usr/loca/bin/python /create-submission.py
echo `ls /output`
