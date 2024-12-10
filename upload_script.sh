#!/bin/bash

# Function for atomic file append
atomic_append() {
    local file="$1"
    local content="$2"
    (
        flock -x 200
        echo "$content" >> "$file"
    ) 200>"$temp_dir/append.lock"
}

# Function for atomic error logging
atomic_error_log() {
    local message="$1"
    (
        flock -x 200
        echo "$message" >> "$temp_dir/errors.txt"
    ) 200>"$temp_dir/error.lock"
}

# Function to display error notification and write to error file
display_error() {
    local message="$1"
    osascript -e "display notification \"$message\" with title \"Error\" subtitle \"Upload Script Error\""
    echo "Error: $message" >&2
    atomic_error_log "$message"
    return 1
}

# Function to check for errors and display final notification
check_completion() {
    local total_files=$(cat "$temp_dir/total_files.txt")
    local processed_count=$(cat "$temp_dir/processed_count.txt")
    
    echo "DEBUG: check_completion called - processed: $processed_count, total: $total_files" >&2
    
    if [ "$processed_count" -eq "$total_files" ]; then
        # Use flock to ensure only one process handles completion
        (
            flock -x 200
            # Check if notification has already been sent first
            if [ ! -f "$temp_dir/notification_sent" ]; then
                echo "DEBUG: All files processed, checking for errors" >&2
                if [ -f "$temp_dir/errors.txt" ]; then
                    local error_messages=$(cat "$temp_dir/errors.txt")
                    osascript -e "display notification \"One or more files failed to upload. Check terminal for details.\" with title \"Error\" subtitle \"Upload Script Error\""
                    echo "The following errors occurred:" >&2
                    echo "$error_messages" >&2
                    rm -rf "$temp_dir"
                    exit 1
                else
                    # Collect URLs and copy to clipboard
                    if [ -f "$temp_dir/urls.txt" ]; then
                        local clipboard_content=$(cat "$temp_dir/urls.txt")
                        if ! echo -n "$clipboard_content" | pbcopy; then
                            display_error "Failed to copy URLs to clipboard"
                            rm -rf "$temp_dir"
                            exit 1
                        fi
                    fi

                    local success_count=$(cat "$temp_dir/success_count.txt")
                    notification_message="Upload complete. $success_count file(s) uploaded successfully."
                    osascript -e "display notification \"$notification_message\" with title \"Success\""
                    touch "$temp_dir/notification_sent"
                    rm -rf "$temp_dir"
                fi
            fi
        ) 200>"$temp_dir/completion.lock"
    fi
}

# Configurable variables
should_speed_up_video=false
target_folder="default"

# Validate input files
if [ $# -eq 0 ]; then
    display_error "No input files provided"
    exit 1  # Main process can exit directly for initial validation
fi

# Set total files before creating temp directory
total_files=$#

# Create temporary directory for concurrent processing
temp_dir=$(mktemp -d)
rm -f "$temp_dir/urls.txt"
rm -f "$temp_dir/errors.txt"
rm -f "$temp_dir/success_count.txt"
rm -f "$temp_dir/processed_count.txt"

# Initialize counters and save total files
echo "0" > "$temp_dir/success_count.txt"
echo "0" > "$temp_dir/processed_count.txt"
echo "$total_files" > "$temp_dir/total_files.txt"

# Validate target folder
if [[ "$target_folder" != "default" && "$target_folder" != "flower-loom" && "$target_folder" != "ai-for-hr-mastermind" ]]; then
    display_error "Invalid target folder: $target_folder. Must be one of 'default', 'flower-loom', or 'ai-for-hr-mastermind'."
    exit 1  # Main process can exit directly for initial validation
fi

# S3 bucket and profile
bucket="public"
profile="jf-public-upload"
endpoint_url="https://s3.jonathanflower.com"
region="us-east-1"

# Verify aws CLI is installed
if ! command -v /opt/homebrew/bin/aws &> /dev/null; then
    display_error "AWS CLI is not installed"
    exit 1  # Main process can exit directly for initial validation
fi

# Verify ffmpeg is installed if video speed-up is enabled
if $should_speed_up_video && ! command -v /opt/homebrew/bin/ffmpeg &> /dev/null; then
    display_error "FFmpeg is not installed but required for video speed-up"
    exit 1  # Main process can exit directly for initial validation
fi

# Function to increment counter atomically
increment_counter() {
    local counter_file="$1"
    (
        flock -x 200
        local current_count=$(cat "$counter_file")
        local new_count=$((current_count + 1))
        echo "$new_count" > "$counter_file"
        echo "$new_count"
    ) 200>"$temp_dir/increment.lock"
}

process_file() {
    local f="$1"
    local total_files=$(cat "$temp_dir/total_files.txt")
    local filename=$(basename "$f")
    local extension=${f##*.}
    local output="/tmp/${filename%.*}_1.4x.$extension"

    # Check if file exists
    if [ ! -f "$f" ]; then
        display_error "File not found: $f"
        increment_counter "$temp_dir/processed_count.txt" > /dev/null
        check_completion
        return 1
    fi

    echo "Processing file: $filename"

    # Speed up the video if enabled
    if $should_speed_up_video; then
        echo "Speeding up video: $f"
        
        # First pass
        if ! /opt/homebrew/bin/ffmpeg -y -i "$f" -filter:v "setpts=PTS/1.4" -af "atempo=1.4" -b:v 1400k -pass 1 -an -f mp4 /dev/null 2>/dev/null; then
            display_error "Failed to process video (first pass): $filename"
            return 1
        fi

        # Second pass
        if ! /opt/homebrew/bin/ffmpeg -i "$f" -filter:v "setpts=PTS/1.4" -af "atempo=1.4" -b:v 1400k -pass 2 "$output" 2>/dev/null; then
            display_error "Failed to process video (second pass): $filename"
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
        increment_counter "$temp_dir/processed_count.txt" > /dev/null
        check_completion
        return 1
    fi

    # After successful upload, increment counters atomically
    local new_success=$(increment_counter "$temp_dir/success_count.txt")
    echo "DEBUG: Incremented success count to $new_success" >&2
    
    local new_processed=$(increment_counter "$temp_dir/processed_count.txt")
    echo "DEBUG: Incremented processed count to $new_processed" >&2

    # Build the URL and add it to the list
    url="$endpoint_url/$bucket/$target_folder/$(basename "$output" | sed 's/ /%20/g')"
    echo "Upload complete. URL: $url"
    atomic_append "$temp_dir/urls.txt" "$url"

    # Clean up temporary file
    if $should_speed_up_video && [ -f "$output" ]; then
        rm "$output" || display_error "Failed to clean up temporary file: $output"
    fi

    # Check if all files have been processed
    check_completion
}

# Process files concurrently
for f in "$@"; do
    process_file "$f" &  # Remove total_files argument since we're reading from file
done

# Wait for all background jobs to complete
wait