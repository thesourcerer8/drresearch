import os

# Prompt user to enter the chip number
chip_number = input("Enter the chip number (e.g., 1, 2, 3, 4): ").strip()

# Validate chip number
if not chip_number.isdigit() or int(chip_number) < 1:
    print("Invalid chip number. Please enter a positive integer.")
    exit()

# Construct file names based on the chip number
files = [f"01_{str(i).zfill(2)}.dump" for i in range(1, 5)]
output_file = f"01_{chip_number.zfill(2)}.dump"

# Create a folder with the same name as the output file (without extension)
output_folder = os.path.splitext(output_file)[0]

# Ensure the output folder exists
os.makedirs(output_folder, exist_ok=True)

# Path for the merged file in the new folder
output_path = os.path.join(output_folder, output_file)

# Merge the files in chunks
chunk_size = 1024 * 1024  # 1 MB per chunk
print(f"\nStarting merge for chip {chip_number}...")

with open(output_path, "wb") as outfile:
    for file in files:
        print(f"Merging: {file}")
        try:
            with open(file, "rb") as infile:
                while chunk := infile.read(chunk_size):
                    outfile.write(chunk)
        except FileNotFoundError:
            print(f"Error: File {file} not found. Aborting.")
            exit()

print("Merge completed.")

# Verify the merged file
print("\n=== Verification ===")
original_sizes = [os.path.getsize(file) for file in files if os.path.exists(file)]
merged_size = os.path.getsize(output_path)

print(f"Total size of original files: {sum(original_sizes)} bytes")
print(f"Size of merged file in new folder: {merged_size} bytes")

if merged_size == sum(original_sizes):
    print(f"Verification successful: The merged file is saved in '{output_path}'.")
else:
    print(f"Verification failed: The merged file size does not match the total size of the original files.")
