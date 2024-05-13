import argparse
import os
import subprocess
import re

def run_command(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, _ = process.communicate()
    status = process.returncode
    return status, output.decode()

parser = argparse.ArgumentParser(description='How to use dmpview')
parser.add_argument('--max_y', type=int, default=-1, help='Display only the first max_y pages/records')
parser.add_argument('--bw', type=int, default=1, help='Display the image as grayscale (0) or black&white (1)')
parser.add_argument('files', nargs='*', help='Files to be displayed on the command line')
args = parser.parse_args()

if not args.files:
    files = [filename for filename in os.listdir('.') if filename.endswith('.dmp')]
else:
    files = args.files

for filename in files:
    pagesize = 512
    match = re.search(r'\((\d+)[bp].*?\)', filename)
    if match:
        pagesize = int(match.group(1))
    match = re.search(r'_m(\d+)[_.]', filename)
    if match:
        pagesize = int(match.group(1)) / 8
    match = re.search(r'\((\d+)[kK].*?\)', filename)
    if match:
        pagesize = int(match.group(1)) * 1024
    match = re.search(r'hmatrix_n(\d+)[_.]', filename)
    if match:
        pagesize = int(match.group(1)) / 8

    fs = os.path.getsize(filename)
    if fs <= 0:
        print(f"Could not load file or file is empty: {filename}")
        continue

    bs = int(fs / pagesize)
    rest = fs % pagesize

    if rest:
        print(f"Warning: There is a rest at the end of the file: {rest} Bytes (please check the pagesize!)")

    maxy = args.max_y if args.max_y >= 0 else bs

    bw = args.bw
    pagesize *= 8 if bw else 1

    convert_cmd = '"C:\\Program Files\\ImageMagick-7.1.1-Q16-HDRI\\magick.exe"'
    cmd = f'{convert_cmd} -depth {"1" if bw else "8"} -size {pagesize}x{maxy} -extract {pagesize}x{maxy}+0+0 "gray:{filename}" output.png'
    status, output = run_command(cmd)
    if status != 0:
        print(f"Error executing command for file {filename}: {output}")
