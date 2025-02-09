# Loom Style Video Upload Utility

I love Loom.  I use it all the time to communicate with my team and stakeholders.  However, the price point is a bit high and really the only feature I want is to speed up the video 1.4x and share a link to the video.  With a little bit of coding, I created a similar tool that I don't have to pay for.  

How it works: Drag a video onto the droplet (Loomify app icon), it will speed up the video 1.4x (Loom style), upload it to an S3-compatible storage, and copy the URL to your clipboard for easy sharing. 

## Who is this for?

It is for people who are comfortable with a very small amount of coding and want to share Loom style videos for free.  

## Features

- Upload videos to S3-compatible storage (MinIO, AWS S3, etc.)
- Optional video speed adjustment using FFmpeg
- Automatic content-type detection (for streaming)
- macOS notifications for upload status
- URL copying to clipboard after successful upload

## My Workflow

I use [OBS](https://obsproject.com/) to record the video, [Presentify](https://presentifyapp.com/) to annotate the video, [Final Cut Pro](https://www.apple.com/final-cut-pro/) to edit the video, and then drag and drop the video onto the Loomify app icon. It will upload it, speed it up 1.4x, and copy the URL to my clipboard. I then paste the URL into my Slack message or wherever I want to share it.

## Prerequisites

- macOS
- Homebrew
- AWS CLI (`brew install awscli`)
- FFmpeg (`brew install ffmpeg`) - required only for video speed adjustment
- an S3-compatible storage bucket with two policies: one for public read access and one for private write access

## How to setup
1. setup your AWS credentials with write access to the bucket
    - `aws configure --profile jf-public-upload`
2. update `upload_script.sh` with if you want it sped up or not, bucket, folder, profile, region, and endpoint_url
3. Open Automator
4. Create a new Application
5. select the "Run Shell Script" action
6. copy the bash script into Automator.
7. save the application
8. drag a video onto the application icon and it will upload it.
9. (optionally) create multiple applications for different target folders and settings.
10. (enable notifications in Sequoia) For notifications to work we need to enable notifications for the Script Editor app.  In order to trigger the request, open and run `trigger - enable - notifications.scpt`

Alternatively, you can run the bash script directly: `./upload_script.sh <file_path>`

## Automator App
This is what it looks like in Automator.  Notice the app on my desktop.  I can drag files onto it and it will upload them.

![Automator App](./automator_app.png)


## FYI
I am using a Synology DSM with MinIO for the S3-compatible storage.  This makes this solution a bit more complex, but it is completely free for me to operate and the uploads are over LAN which makes them very fast.  

If my videos get a lot of traffic, I plan to add a CDN via Cloudflare to the mix.

## Great Video Recording Applications

- [Screenity](https://screenity.io/en/): A powerful screen recording tool with annotation features. *(Free)*
- [Komodo Decks](https://komododecks.com/): A collaborative video recording platform for teams. *(Paid)*
- [Veed.io](https://www.veed.io/): An online video editing and recording tool with various features. *(Paid)*
- [OBS Studio](https://obsproject.com/): A free and open-source software for video recording and live streaming. *(Free)*
- Quicktime: Built into macOS, Quicktime offers basic video recording and editing capabilities. *(Free)*
- [Screen Studio](https://screen.studio/): A professional screen recording and editing tool with automatic zooming and smooth animations. *(Paid)*
- [Neeto Record](https://neeto.com/neetorecord): A screen recording tool with instant sharing and collaboration features. *(Free/Paid)* (This is the best full featured tool with a generous free tier I have found)
