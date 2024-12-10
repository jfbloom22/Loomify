#!/bin/bash

# Configurable variables
should_speed_up_video=false # Set to false if you don't want to speed up the video
target_folder="default"    # Options: 'default', 'flower-loom', 'ai-for-hr-mastermind'

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

# Array to collect URLs
uploaded_urls=()

echo "Processing ${#@} file(s)..."

for f in "$@"
do
    filename=$(basename "$f")
    extension=${f##*.}
    output="/tmp/${filename%.*}_1.4x.$extension"

    echo "Processing file: $filename"

    # Speed up the video if enabled
    if $should_speed_up_video; then
        echo "Speeding up video: $f"

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
        content_type="video/quicktime"
    else
        content_type="application/octet-stream"
    fi

    # Upload to MinIO (S3-compatible bucket) with Content-Type metadata
    echo "Uploading $output to s3://$bucket/$target_folder/ with Content-Type: $content_type"
    aws --profile "$profile" s3 cp "$output" "s3://$bucket/$target_folder/" \
        --endpoint-url "$endpoint_url" \
        --region "$region" \
        --content-type "$content_type"

    # Build the URL and add it to the list
    url="$endpoint_url/$bucket/$target_folder/$(basename "$output" | sed 's/ /%20/g')"
    echo "Upload complete. URL: $url"
    uploaded_urls+=("$url")

    # Optionally, delete the temporary file if it was created
    if $should_speed_up_video; then
        rm "$output"
    fi
done

# Combine URLs into a single clipboard entry
clipboard_content=$(printf "%s\n" "${uploaded_urls[@]}")
echo -n "$clipboard_content" | pbcopy

# Prepare notification message for Automator
notification_message="All uploads complete. ${#uploaded_urls[@]} file(s) uploaded successfully."

osascript -e "display notification \"$notification_message\" with title \"Success\""