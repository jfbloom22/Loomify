#!/bin/bash

# Function to display error notification and exit
display_error() {
    local message="$1"
    osascript -e "display notification \"$message\" with title \"Error\" subtitle \"Upload Script Error\""
    echo "Error: $message" >&2
    exit 1
}

# Configurable variables
should_speed_up_video=false
target_folder="default"

# Validate input files
if [ $# -eq 0 ]; then
    display_error "No input files provided"
fi

# Validate target folder
if [[ "$target_folder" != "default" && "$target_folder" != "flower-loom" && "$target_folder" != "ai-for-hr-mastermind" ]]; then
    display_error "Invalid target folder: $target_folder. Must be one of 'default', 'flower-loom', or 'ai-for-hr-mastermind'."
fi

# S3 bucket and profile
bucket="public"
profile="jf-public-upload"
endpoint_url="https://s3.jonathanflower.com"
region="us-east-1"

# Verify aws CLI is installed
if ! command -v /opt/homebrew/bin/aws &> /dev/null; then
    display_error "AWS CLI is not installed"
fi

# Verify ffmpeg is installed if video speed-up is enabled
if $should_speed_up_video && ! command -v /opt/homebrew/bin/ffmpeg &> /dev/null; then
    display_error "FFmpeg is not installed but required for video speed-up"
fi

# Array to collect URLs
uploaded_urls=()

echo "Processing ${#@} file(s)..."

for f in "$@"
do
    # Check if file exists
    if [ ! -f "$f" ]; then
        display_error "File not found: $f"
    fi

    filename=$(basename "$f")
    extension=${f##*.}
    output="/tmp/${filename%.*}_1.4x.$extension"

    echo "Processing file: $filename"

    # Speed up the video if enabled
    if $should_speed_up_video; then
        echo "Speeding up video: $f"
        
        # First pass
        if ! /opt/homebrew/bin/ffmpeg -y -i "$f" -filter:v "setpts=PTS/1.4" -af "atempo=1.4" -b:v 1400k -pass 1 -an -f mp4 /dev/null 2>/dev/null; then
            display_error "Failed to process video (first pass): $filename"
        fi

        # Second pass
        if ! /opt/homebrew/bin/ffmpeg -i "$f" -filter:v "setpts=PTS/1.4" -af "atempo=1.4" -b:v 1400k -pass 2 "$output" 2>/dev/null; then
            display_error "Failed to process video (second pass): $filename"
        fi
    else
        output="$f"
    fi

    # Determine the Content-Type
    case "$extension" in
        mp4)
            content_type="video/mp4"
            ;;
        mov)
            content_type="video/quicktime" # note that MOV will not stream
            ;;
        *)
            content_type="application/octet-stream"
            ;;
    esac

    # Notify if MOV file is uploaded since it won't stream in browser
    if [ "$extension" = "mov" ]; then
        osascript -e "display notification \"Note: MOV files will not stream in browser\" with title \"Warning\""
        echo "Warning: MOV files will not stream in browser"
    fi

    # Upload to MinIO with error handling
    echo "Uploading $output to s3://$bucket/$target_folder/ with Content-Type: $content_type"
    if ! /opt/homebrew/bin/aws --profile "$profile" s3 cp "$output" "s3://$bucket/$target_folder/" \
        --endpoint-url "$endpoint_url" \
        --region "$region" \
        --content-type "$content_type"; then
        display_error "Failed to upload file: $filename"
    fi

    # Build the URL and add it to the list
    url="$endpoint_url/$bucket/$target_folder/$(basename "$output" | sed 's/ /%20/g')"
    echo "Upload complete. URL: $url"
    uploaded_urls+=("$url")

    # Clean up temporary file
    if $should_speed_up_video && [ -f "$output" ]; then
        rm "$output" || display_error "Failed to clean up temporary file: $output"
    fi
done

# Copy URLs to clipboard with error handling
clipboard_content=$(printf "%s\n" "${uploaded_urls[@]}")
if ! echo -n "$clipboard_content" | pbcopy; then
    display_error "Failed to copy URLs to clipboard"
fi

# Get the actual count of processed files
file_count=$#

# Display success notification with correct count
notification_message="All uploads complete. $file_count file(s) uploaded successfully."
osascript -e "display notification \"$notification_message\" with title \"Success\""