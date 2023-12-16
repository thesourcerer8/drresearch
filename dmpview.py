import os
import re
import argparse
import subprocess
from pathlib import Path

def run_command(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, error = process.communicate()
    return process.returncode, output.decode('utf-8'), error.decode('utf-8')

def main():
    parser = argparse.ArgumentParser(description='How to use dmpview')
    parser.add_argument('--max_y', type=int, default=-1, help='Display only the first N pages/records')
    parser.add_argument('--bw', type=int, default=1, help='Display the image as grayscale (0) or black & white (1)')
    parser.add_argument('--display_help', action='store_true', help='Display help message')
    args, file_list = parser.parse_known_args()

    if args.display_help:
        print("How to use dmpview:")
        print("You can call dmpview without any arguments, then it will display all the .dmp files in the current directory.")
        print("You can specify single files to be displayed on the command line.")
        print("Parameters:")
        print("  dmpview --max_y=100  -> display only the first 100 pages/records")
        print("  dmpview --bw=0  -> display the image as grayscale")
        print("  dmpview --bw=1 -> display the image as black & white")
        exit()

    imagemagick_path = r'C:\Program Files\ImageMagick-7.1.1-Q16-HDRI'
    maxy = args.max_y if args.max_y >= 0 else -1

    for fn in file_list:
        pagesize = 512
        match = re.search(r'\((\d+)[bp].*?\)', fn)
        if match:
            pagesize = int(match.group(1))
        # ... (additional patterns for pagesize)

        fs = os.path.getsize(fn)
        if fs <= 0:
            print(f"Could not load file or file is empty: {fn}")
            continue

        bs = fs // pagesize
        rest = fs % pagesize

        if rest:
            print(f"Warning: There is a rest at the end of the file: {rest} Bytes (please check the pagesize!)")

        maxy = bs if maxy < 0 else maxy

        pagesize *= 8 if args.bw else 1

        convert_cmd = Path(imagemagick_path) / 'magick.exe'

        # Resize and crop the image
        resize_and_crop_cmd = f'"{convert_cmd}" -depth {1 if args.bw else 8} -size {pagesize}x{maxy} "gray:{fn}" output.png'
        subprocess.run(resize_and_crop_cmd, shell=True)

if __name__ == "__main__":
    main()
