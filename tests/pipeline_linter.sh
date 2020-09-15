#!/bin/bash

while getopts t:f: option
  do
    case "${option}"
      in
        t) TOKEN=${OPTARG};;
        f) FILE=${OPTARG};;
    esac
  done

OUTPUT=$(curl -H "Authorization: OAuth $TOKEN" -X POST -F "jenkinsfile=<$FILE" https://osci-jenkins-2.ci.fedoraproject.org/pipeline-model-converter/validate)

if [[ "$OUTPUT" =~ .*"successfully validated".* ]]; then
  exit 0
else
  exit 1
fi

