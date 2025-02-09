#!/bin/bash

# Configurable variables
should_speed_up_video=true
target_folder="ai-for-hr-mastermind" # default, flower-loom, ai-for-hr-mastermind

# S3 configuration
bucket="public"
profile="jf-public-upload"
endpoint_url="https://s3.jonathanflower.com"
region="us-east-1"

# Function to display error notification
display_error() {
    local message="$1"
    osascript -e "display notification \"$message\" with title \"Error\" subtitle \"Upload Script Error\""
    echo "Error: $message" >&2
    return 1
}

# Function to display success notification
display_success() {
    local message="$1"
    osascript -e "display notification \"$message\" with title \"Success\" subtitle \"Upload Script Success\""
    echo "Success: $message"
}

# Function to display notification
display_notification() {
    local message="$1"
    osascript -e "display notification \"$message\" with title \"Upload Script\" subtitle \"Upload Script\""
    echo "Notification: $message"
}

# notify that the script is starting
display_notification "Upload script starting"

# Validate input file
if [ $# -ne 1 ]; then
    display_error "Please provide exactly one input file"
    exit 1
fi

# Validate target folder
if [[ "$target_folder" != "default" && "$target_folder" != "flower-loom" && "$target_folder" != "ai-for-hr-mastermind" ]]; then
    display_error "Invalid target folder: $target_folder. Must be one of 'default', 'flower-loom', or 'ai-for-hr-mastermind'."
    exit 1
fi

# Verify aws CLI is installed
if ! command -v /opt/homebrew/bin/aws &> /dev/null; then
    display_error "AWS CLI is not installed"
    exit 1
fi

# Verify ffmpeg is installed if video speed-up is enabled
if $should_speed_up_video && ! command -v /opt/homebrew/bin/ffmpeg &> /dev/null; then
    display_error "FFmpeg is not installed but required for video speed-up"
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
    
    # First pass
    if ! /opt/homebrew/bin/ffmpeg -y -i "$input_file" -filter:v "setpts=PTS/1.4" -af "atempo=1.4" -b:v 1400k -pass 1 -an -f mp4 /dev/null 2>/dev/null; then
        display_error "Failed to speed up video (first pass): $filename"
        exit 1
    fi

    # Second pass
    if ! /opt/homebrew/bin/ffmpeg -i "$input_file" -filter:v "setpts=PTS/1.4" -af "atempo=1.4" -b:v 1400k -pass 2 "$output" 2>/dev/null; then
        display_error "Failed to speed up video (second pass): $filename"
        exit 1
    fi
else
    output="$input_file"
fi

# Determine the Content-Type
case "$extension" in
    mp4)
        content_type="video/mp4"
        ;;
    mov)
        content_type="video/quicktime"
        mov_warning=" Note: MOV files will not stream in browser."
        ;;
    *)
        content_type="application/octet-stream"
        ;;
esac

# Upload to MinIO
echo "Uploading $output to s3://$bucket/$target_folder/ with Content-Type: $content_type"
if ! /opt/homebrew/bin/aws --profile "$profile" s3 cp "$output" "s3://$bucket/$target_folder/" \
    --endpoint-url "$endpoint_url" \
    --region "$region" \
    --content-type "$content_type"; then
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