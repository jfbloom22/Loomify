#!/bin/bash

# Configurable variables
should_speed_up_video=true
target_folder="flower-loom" # default, flower-loom, ai-for-hr-mastermind

# S3 configuration
bucket="public"
profile="jf-public-upload"
endpoint_url="https://s3.jonathanflower.com"
region="us-east-1"

display_error() {
    osascript -e "display notification \"$1\" with title \"Error\" subtitle \"Upload Script Error\""
    echo "Error: $1" >&2
    return 1
}

display_success() {
    osascript -e "display notification \"$1\" with title \"Success\" subtitle \"Upload Script Success\""
    echo "Success: $1"
}

display_notification() {
    osascript -e "display notification \"$1\" with title \"Upload Script\" subtitle \"Upload Script\""
    echo "Notification: $1"
}

display_notification "Upload script starting"

# Validate input file
if [ $# -ne 1 ]; then
    display_error "Please provide exactly one input file"
    exit 1
fi

# Validate target folder
if [[ "$target_folder" != "default" && "$target_folder" != "ai-for-hr-mastermind" && "$target_folder" != "flower-loom" ]]; then
    display_error "Invalid target folder: $target_folder."
    exit 1
fi

# Verify aws CLI is installed
if ! command -v /opt/homebrew/bin/aws &> /dev/null; then
    display_error "AWS CLI is not installed"
    exit 1
fi

# Verify ffmpeg is installed if video speed-up is enabled
if $should_speed_up_video && ! command -v /opt/homebrew/bin/ffmpeg &> /dev/null; then
    display_error "FFmpeg is not installed but required"
    exit 1
fi

input_file="$1"
filename=$(basename "$input_file")
extension=${input_file##*.}
output="/tmp/${filename%.*}_1.4x.$extension"

# Check if file exists
if [ ! -f "$input_file" ]; then
    display_error "File not found: $filename"
    exit 1
fi

echo "Processing file: $filename"

# Speed up the video if enabled
if $should_speed_up_video; then
    echo "Speeding up video: $input_file"

    # Re-encode in one pass with Baseline profile and faststart
    if ! /opt/homebrew/bin/ffmpeg -y -i "$input_file" \
      -filter:v "setpts=PTS/1.4" -af "atempo=1.4" \
      -c:v libx264 -profile:v baseline -level 3.0 \
      -c:a aac -movflags +faststart -preset slow \
      -b:v 1400k -maxrate 1400k -bufsize 2800k \
      "$output"; then
        display_error "FFmpeg encoding failed for: $filename"
        exit 1
    fi
else
    output="$input_file"
fi

case "$extension" in
    mp4) content_type="video/mp4" ;;
    mov) content_type="video/quicktime"; mov_warning=" Note: MOV files will not stream in browser." ;;
    *)   content_type="application/octet-stream" ;;
esac

# Upload to MinIO
echo "Uploading $output to s3://$bucket/$target_folder/ with Content-Type: $content_type"
if ! AWS_MAX_ATTEMPTS=1 AWS_RETRY_MODE=standard \
AWS_DEFAULT_REGION="$region" \
/opt/homebrew/bin/aws --profile "$profile" s3api put-object \
    --bucket "$bucket" \
    --key "$target_folder/$(basename "$output")" \
    --body "$output" \
    --endpoint-url "$endpoint_url" \
    --content-type "$content_type" \
    --content-disposition "inline"; then
    display_error "Upload failed for: $filename"
    exit 1
fi

# Build and copy the URL
url="$endpoint_url/$bucket/$target_folder/$(basename "$output" | sed 's/ /%20/g')"
if ! echo -n "$url" | pbcopy; then
    display_error "Failed to copy URL to clipboard"
    exit 1
fi

# Clean up temporary file
if $should_speed_up_video && [ -f "$output" ]; then
    rm "$output" || echo "Warning: Failed to clean up temporary file: $output"
fi

# Show success notification
notification_message="Upload complete. URL copied to clipboard.$mov_warning"
display_success "$notification_message"

echo "Upload complete. URL: $url"