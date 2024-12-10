#!/bin/bash

# Configurable variables
should_speed_up_video=false # Set to false if you don't want to speed up the video
target_folder="default"    # Options: 'default', 'flower-loom', 'ai-for-hr-mastermind'

# Validate target folder
if [[ "$target_folder" != "default" && "$target_folder" != "flower-loom" && "$target_folder" != "ai-for-hr-mastermind" ]]; then
    echo "Invalid target folder: $target_folder. Must be one of 'default', 'flower-loom', or 'ai-for-hr-mastermind'."
    exit 1
fi

# S3 bucket name
bucket="public"

for f in "$@"
do
    filename=$(basename "$f" .${f##*.})
    extension=${f##*.}
    output="$f" # Initialize output with the original file

    # Speed up the video if enabled
    if $should_speed_up_video; then
        echo "Speeding up video: $f"
        output="/tmp/${filename}_1.4x.$extension"

        # First pass
        /opt/homebrew/bin/ffmpeg -y -i "$f" -filter:v "setpts=PTS/1.4" -af "atempo=1.4" -b:v 1400k -pass 1 -an -f mp4 /dev/null

        # Second pass
        /opt/homebrew/bin/ffmpeg -i "$f" -filter:v "setpts=PTS/1.4" -af "atempo=1.4" -b:v 1400k -pass 2 "$output"
    else
        echo "Skipping video speed-up for: $f"
    fi

    # Upload to S3-compatible bucket
    echo "Uploading $output to s3://$bucket/$target_folder/"
    aws --profile jf-public-upload s3 cp "$output" "s3://$bucket/$target_folder/"

    # Optionally, delete the temporary file if it was created
    if $should_speed_up_video; then
        rm "$output"
    fi
done