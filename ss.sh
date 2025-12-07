#!/bin/bash

url="https://captions.vimeo.com/captions/191046661.vtt?expires=1765113130&sig=bf07bcfa8a34c9fb1b10dc40bbc06324be58d53a"

# Fetch data from the URL
data=$(curl -s "$url")

# Process the data to remove timestamps, format it into a single line, and remove consecutive numbers
output=$(echo "$data" | sed -E 's/^[0-9:.]+ --> [0-9:.]+\s*//' | tr -s '\n' | tr '\n' ' ' | tr -s ' ' | sed -E 's/[[:space:]]+[0-9]+[[:space:]]+/ /g')

path="/workspaces/kubernetes_and_cloud_native_associate/KubernetesResources/"

mkdir -p $path

# Append the processed output to the README.md file
echo -e "\n\n$output" >> ${path}README.md

# In case Auto-generated subitles are being used.
# curl -s  https://player.vimeo.com/texttrack/170006530.vtt?token=66ca47bb_0x72018351bd1058d762864c42907ceb493a06893f | grep -vE '^[0-9]+$|^[0-9]+:[0-9]+:[0-9]+\.[0-9]+ --> [0-9]+:[0-9]+:[0-9]+\.[0-9]+$|^WEBVTT$|^$' | tr '\n' ' '

# git add . && git commit -m 'added notes' && git push