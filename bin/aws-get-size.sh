#!/bin/bash

aws s3 ls --summarize --human-readable --recursive --profile wasabi s3://amanda-cloud-backup-test
