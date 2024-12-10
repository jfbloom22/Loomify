#!/bin/bash

# Configurable variables
should_speed_up_video=false # Set to false if you don't want to speed up the video
target_folder="ai-for-hr-mastermind"    # Options: 'default', 'flower-loom', 'ai-for-hr-mastermind'

# Validate target folder
if [[ "$target_folder" != "default" && "$target_folder" != "flower-loom" && "$target_folder" != "ai-for-hr-mastermind" ]]; then
    echo "Invalid target folder: $target_folder. Must be one of 'default', 'flower-loom', or 'ai-for-hr-mastermind'."
    exit 1
fi

# S3 bucket and profile
bucket="public"
profile="jf-public-upload"
endpoint_url="https://s3.jonathanflower.com"
region="us-east-1"

for f in "$@"
do
    filename=$(basename "$f" .${f##*.})
    extension=${f##*.}
    output="/tmp/${filename}.$extension"

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
        output="$f" # Use the original file if not speeding up
    fi
    # Determine the Content-Type based on file extension
    if [[ "$extension" == "mp4" ]]; then
        content_type="video/mp4"
    elif [[ "$extension" == "mov" ]]; then
    # note: minio will not stream .mov
        content_type="video/quicktime"
    else
        content_type="application/octet-stream"
    fi
    # Upload to MinIO (S3-compatible bucket) without multipart
    echo "Uploading $output to s3://$bucket/$target_folder/ with Content-Type: $content_type"
    /opt/homebrew/bin/aws --profile "$profile" s3 cp "$output" "s3://$bucket/$target_folder/" \
        --endpoint-url "$endpoint_url" \
        --region "$region" \
        --content-type "$content_type"

    # Build the URL and copy it to the clipboard
    url="$endpoint_url/$bucket/$target_folder/$(basename "$output" | sed 's/ /%20/g')"
    echo "Upload complete. URL: $url"
    echo -n "$url" | pbcopy

    # Optionally, delete the temporary file if it was created
    if $should_speed_up_video; then
        rm "$output"
    fi
done