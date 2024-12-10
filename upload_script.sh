#!/bin/bash

# Function to display error notification and write to error file
display_error() {
    local message="$1"
    osascript -e "display notification \"$message\" with title \"Error\" subtitle \"Upload Script Error\""
    echo "Error: $message" >&2
    return 1
}

# Configurable variables
should_speed_up_video=false
target_folder="default"

# Array to track results
declare -a uploaded_urls=()
declare -a failed_files=()
declare -a mov_files=()

# Validate input files
if [ $# -eq 0 ]; then
    display_error "No input files provided"
    exit 1
fi

# Validate target folder
if [[ "$target_folder" != "default" && "$target_folder" != "flower-loom" && "$target_folder" != "ai-for-hr-mastermind" ]]; then
    display_error "Invalid target folder: $target_folder. Must be one of 'default', 'flower-loom', or 'ai-for-hr-mastermind'."
    exit 1
fi

# S3 bucket and profile
bucket="public"
profile="jf-public-upload"
endpoint_url="https://s3.jonathanflower.com"
region="us-east-1"

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

process_file() {
    local f="$1"
    local filename=$(basename "$f")
    local extension=${f##*.}
    local output="/tmp/${filename%.*}_1.4x.$extension"

    # Check if file exists
    if [ ! -f "$f" ]; then
        failed_files+=("$filename (File not found)")
        return 1
    fi

    echo "Processing file: $filename"

    # Speed up the video if enabled
    if $should_speed_up_video; then
        echo "Speeding up video: $f"
        
        # First pass
        if ! /opt/homebrew/bin/ffmpeg -y -i "$f" -filter:v "setpts=PTS/1.4" -af "atempo=1.4" -b:v 1400k -pass 1 -an -f mp4 /dev/null 2>/dev/null; then
            failed_files+=("$filename (Failed first pass)")
            return 1
        fi

        # Second pass
        if ! /opt/homebrew/bin/ffmpeg -i "$f" -filter:v "setpts=PTS/1.4" -af "atempo=1.4" -b:v 1400k -pass 2 "$output" 2>/dev/null; then
            failed_files+=("$filename (Failed second pass)")
            return 1
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
            mov_files+=("$filename")
            ;;
        *)
            content_type="application/octet-stream"
            ;;
    esac

    # Upload to MinIO with error handling
    echo "Uploading $output to s3://$bucket/$target_folder/ with Content-Type: $content_type"
    if ! /opt/homebrew/bin/aws --profile "$profile" s3 cp "$output" "s3://$bucket/$target_folder/" \
        --endpoint-url "$endpoint_url" \
        --region "$region" \
        --content-type "$content_type"; then
        failed_files+=("$filename (Upload failed)")
        return 1
    fi

    # Build the URL and add it to the list
    url="$endpoint_url/$bucket/$target_folder/$(basename "$output" | sed 's/ /%20/g')"
    echo "Upload complete. URL: $url"
    uploaded_urls+=("$url")

    # Clean up temporary file
    if $should_speed_up_video && [ -f "$output" ]; then
        rm "$output" || echo "Warning: Failed to clean up temporary file: $output"
    fi
}

# Process files sequentially
for f in "$@"; do
    process_file "$f"
done

# Display results
if [ ${#failed_files[@]} -ne 0 ]; then
    error_message="The following files failed:"
    for failed_file in "${failed_files[@]}"; do
        error_message+="\n- $failed_file"
    done
    display_error "$error_message"
    exit 1
else
    # Copy URLs to clipboard
    clipboard_content=$(printf "%s\n" "${uploaded_urls[@]}")
    if ! echo -n "$clipboard_content" | pbcopy; then
        display_error "Failed to copy URLs to clipboard"
        exit 1
    fi

    # Show success notification
    notification_message="Upload complete. ${#uploaded_urls[@]} file(s) uploaded successfully."
    osascript -e "display notification \"$notification_message\" with title \"Success\""

    # Show MOV warning if any MOV files were uploaded
    if [ ${#mov_files[@]} -gt 0 ]; then
        sleep 1  # Brief pause between notifications
        osascript -e "display notification \"One or more MOV files were uploaded. These files will not stream in browser.\" with title \"Warning\""
    fi
fi