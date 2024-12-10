import os
# for multi upload support checkout commit: 4d1740eafa99d63ccdbdba7cf772b2f2140bab0b and use this python script
# opted against this for now becuase we like things very simple
# this is necessary since Automator doesn't support passing multiple files to a script, it calls the script once for each file
def main():
    # Get the directory containing this script
    script_dir = os.path.dirname(os.path.realpath(__file__))
    
    # Path to the upload script
    upload_script = os.path.join(script_dir, 'upload_script.sh')
    
    # Make sure upload script is executable
    os.chmod(upload_script, 0o755)
    
    # Get all input files from stdin (how Automator passes files)
    input_files = []
    for line in sys.stdin:
        filepath = line.strip()
        if filepath:
            input_files.append(filepath)
    
    if not input_files:
        print("No files provided", file=sys.stderr)
        sys.exit(1)
    
    # Execute upload script with all files at once
    try:
        cmd = [upload_script] + input_files
        env = os.environ.copy()
        env['AUTOMATOR_PATH'] = os.path.realpath(__file__)
        
        result = subprocess.run(
            cmd,
            env=env,
            check=True,
            text=True
        )
        
    except subprocess.CalledProcessError as e:
        print(f"Upload script failed with exit code {e.returncode}", file=sys.stderr)
        sys.exit(e.returncode)

if __name__ == "__main__":
    main()