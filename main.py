import sys
import os
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import boto3
import subprocess
from dotenv import load_dotenv
import threading

# Hardcoded configuration
AWS_ENDPOINT_URL = 'https://s3.jonathanflower.com'
AWS_ACCESS_KEY_ID = 'jf-public-upload'
AWS_SECRET_ACCESS_KEY = 'VDK4nym9tny-tma.ygc'
DEFAULT_BUCKET = 'public'

# Predefined folder list
folders = ["default", "ai-for-hr-mastermind"]

# Initialize main window
root = tk.Tk()
root.title("S3 File Uploader")
root.geometry("500x400")


file_path = None
speed_up_video = tk.BooleanVar(value=False)  # Toggle for speeding up video

def set_file_from_args():
    """Set the file path if a file is dragged onto the app icon."""
    global file_path
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
        if os.path.isfile(file_path):
            file_label.config(text=f"Selected: {os.path.basename(file_path)}")
        else:
            file_path = None
            messagebox.showerror("Error", "Invalid file provided as argument.")

def select_file():
    """Open a file dialog to select a file."""
    global file_path
    file_path = filedialog.askopenfilename(filetypes=[("Video Files", "*.mp4 *.mov *.avi *.mkv")])
    if file_path:
        file_label.config(text=f"Selected: {os.path.basename(file_path)}")
    else:
        file_label.config(text="No file selected.")

def process_video(input_file):
    """Process the video to speed it up by 1.4x."""
    try:
        filename = os.path.splitext(os.path.basename(input_file))[0]
        extension = os.path.splitext(input_file)[1]
        output_dir = "/Users/jflowerhome/SynologyDrive/Recordings/"
        os.makedirs(output_dir, exist_ok=True)
        output_file = os.path.join(output_dir, f"{filename}_1.4x{extension}")

        # Run ffmpeg commands
        subprocess.run([
            "/opt/homebrew/bin/ffmpeg", "-y", "-i", input_file,
            "-filter:v", "setpts=PTS/1.4", "-af", "atempo=1.4", "-b:v", "1400k",
            "-pass", "1", "-an", "-f", "mp4", "/dev/null"
        ], check=True)
        subprocess.run([
            "/opt/homebrew/bin/ffmpeg", "-i", input_file,
            "-filter:v", "setpts=PTS/1.4", "-af", "atempo=1.4", "-b:v", "1400k",
            "-pass", "2", output_file
        ], check=True)
        return output_file
    except subprocess.CalledProcessError as e:
        messagebox.showerror("Error", f"Video processing failed: {e}")
        return None

def send_notification(title, message):
    """Send a macOS push notification."""
    try:
        subprocess.run([
            "osascript", "-e",
            f'display notification "{message}" with title "{title}"'
        ], check=True)
    except Exception as e:
        print(f"Failed to send notification: {e}")

def upload_to_s3():
    """Upload the selected file to S3."""
    if not file_path:
        messagebox.showerror("Error", "No file selected.")
        return

    try:
        # Start the progress bar
        progress_bar.start()

        # Process video if speed-up option is selected
        upload_file = file_path
        if speed_up_video.get():
            upload_file = process_video(file_path)
            if not upload_file:
                progress_bar.stop()
                return

        # Create S3 client
        s3 = boto3.client(
            's3',
            endpoint_url=AWS_ENDPOINT_URL,
            aws_access_key_id=AWS_ACCESS_KEY_ID,
            aws_secret_access_key=AWS_SECRET_ACCESS_KEY
        )

        # Build S3 key with folder prefix
        folder_name = folder_var.get()
        s3_key = f"{folder_name}/{os.path.basename(upload_file)}"

        # Upload file using put_object
        with open(upload_file, 'rb') as data:
            s3.put_object(Bucket=DEFAULT_BUCKET, Key=s3_key, Body=data)

        progress_bar.stop()
        send_notification("Upload Complete", f"File uploaded to folder '{folder_name}' successfully.")
        root.destroy()  # Close the app
    except Exception as e:
        progress_bar.stop()
        messagebox.showerror("Error", f"Failed to upload file: {e}")
        root.destroy()  # Close the app

def start_upload_thread():
    """Run the upload function in a separate thread."""
    threading.Thread(target=upload_to_s3).start()

# Label
label = tk.Label(root, text="Select a file to upload to S3", font=("Helvetica", 12))
label.pack(pady=10)

# File selection button
file_button = tk.Button(root, text="Select File", command=select_file)
file_button.pack(pady=10)

# Label to display selected file
file_label = tk.Label(root, text="No file selected.", font=("Helvetica", 10))
file_label.pack(pady=10)

# Speed-up option
speed_checkbox = tk.Checkbutton(root, text="Speed up video by 1.4x", variable=speed_up_video)
speed_checkbox.pack(pady=10)

# Folder selection dropdown
folder_var = tk.StringVar(root)
folder_var.set("default")  # Default folder
folder_menu = tk.OptionMenu(root, folder_var, *folders)
folder_menu.pack(pady=10)

# Progress bar
progress_bar = ttk.Progressbar(root, mode='indeterminate', length=300)
progress_bar.pack(pady=20)

# Upload button
upload_button = tk.Button(root, text="Upload", command=start_upload_thread)
upload_button.pack(pady=10)

# Check for file passed via arguments
set_file_from_args()

root.mainloop()