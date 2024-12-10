# Loom Style Video Upload Utility

I love Loom.  I use it all the time to communicate with my team and stakeholders.  However, the price point is a bit high and really the only feature I want is to speed up the video 1.4x.  So, I created a similar tool that I don't have to pay for.  

Drag a video onto the droplet, it will be speed up the video 1.4x (Loom style), uploaded to an S3-compatible storage, and copy the URL to your clipboard for easy sharing. 

## Features

- Upload videos to S3-compatible storage (MinIO, AWS S3, etc.)
- Optional video speed adjustment using FFmpeg
- Automatic content-type detection
- macOS notifications for upload status
- URL copying to clipboard after successful upload
- Support for multiple target folders

## Prerequisites

- macOS
- Homebrew
- AWS CLI (`brew install awscli`)
- FFmpeg (`brew install ffmpeg`) - required only for video speed adjustment

## How to use
1. setup your AWS credentials
2. run the bash script: `./upload_script.sh <file_path>`
3. copy the bash script into an Automator Application.  This is prefered because it helps turn the bash script into a MacOs app that you can drag files onto.  

## Automator App
This is what it looks like in Automator.  Notice the app on my desktop.  I can drag files onto it and it will upload them.

![Automator App](./automator_app.png)
