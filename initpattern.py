import sys
import ctypes
from ctypes import wintypes

kernel32 = ctypes.windll.kernel32

def idema_gb2lba(advertised):
    return 97696368 + (1953504 * (advertised - 50))

def get_last_error_string():
    error_code = kernel32.GetLastError()
    if error_code == 0:
        return "No Error"
    message_buffer = ctypes.create_string_buffer(2000)
    size = kernel32.FormatMessageA(
        0x00000100 | 0x00000200 | 0x00001000,
        None,
        error_code,
        0,
        message_buffer,
        ctypes.sizeof(message_buffer),
        None
    )
    return message_buffer[:size].decode("utf-8")

def show_usage():
    sys.stderr.write("Usage: initpattern.exe \\\\.\\PhysicalDrive1 [size in MB] [data area size in Byte]\n")
    print("Available disks:")
    system("wmic diskdrive list brief")

def main(argv):
    Ropen = wintypes.DWORD()
    wearedone = 0
    sector = 0
    target_size = -1  # in Bytes
    p_write_block = bytearray(4096)
    p_write_sector = p_write_block
    DATA_size = 512  # in Bytes
    xml_fn = "pattern.xml"
    handle = None

    if len(argv) < 2:
        show_usage()
        return -1

    if len(argv) > 2:
        if len(argv[2]) > 2 and argv[2][-2:] == "GB":
            target_size = idema_gb2lba(int(argv[2][:-2])) * 512
            print(f"Setting the target size to {target_size>>11} MB / {target_size} sectors / {target_size>>30} GiB.")
        else:
            target_size = int(argv[2]) << 11
            print(f"Setting the target size to {target_size>>11} MB / {target_size} sectors / {target_size>>30} GiB.")
        xml_fn = f"{argv[1]}.xml"

    if len(argv) > 3:
        DATA_size = int(argv[3])
        print(f"Setting the DATA size to {DATA_size}")

    ecc_real = (DATA_size // 512) + 1
    majority = 5

    border0 = 512 * 1024 * 2  # 512MB pattern
    border7 = 1024 * 1024 * 2  # 512MB 00
    borderf = 1280 * 1024 * 2  # 256 MB 77
    borderphi = 1536 * 1024 * 2  # 256 MB FF
    border_ecc = borderphi + ecc_real * ecc_real * majority * DATA_size * 8 + 1

    h_device = kernel32.CreateFileA(argv[1], 0x80000000 | 0x40000000, 0x1 | 0x2, None, 3, 0, None)

    if h_device == -1:
        h_device = kernel32.CreateFileA(argv[1], 0x80000000 | 0x40000000, 0x1 | 0x2, None, 4, 0, None)
        if h_device == -1:
            print(f"CreateFileA returned an error when trying to open the file: {get_last_error_string()}")
            return 0

    print("Opened successfully")

    ctypes_buffer = ctypes.create_string_buffer(bytes(p_write_block))
    kernel32.DeviceIoControl(h_device, 0x00090000, None, 0, ctypes.byref(ctypes_buffer), 4096, ctypes.byref(Ropen), None)


    lpBytesReturned = wintypes.DWORD()
    kernel32.DeviceIoControl(h_device, 0x0007405C, None, 0, ctypes.byref(ctypes_buffer), 4096, ctypes.byref(lpBytesReturned), None)
    if lpBytesReturned.value == 8:
        target_size = ctypes.cast(p_write_block, ctypes.POINTER(wintypes.ULONGLONG)).contents.value
        print(f"Device Size: {target_size} ({target_size//1000//1000//1000}GB)")
    else:
        print(f"Image Size: {target_size} ({target_size//1000//1000//1000}GB)")

    if not target_size:
        sys.stderr.write("ERROR: The target size of the disk/card/dumpfile is null.\n")
        show_usage()
        return -2

    if target_size < (border_ecc << 9):
        print(f"WARNING: The pattern required for a data size of {DATA_size} is too large to fit into this device/image! Enlarge the image size to at least {border_ecc//2//1024} MB or change the pattern configuration")
        while target_size < (border_ecc << 9) and DATA_size > 512:
            DATA_size //= 2
            ecc_real = (DATA_size // 512) + 1
            border_ecc = borderphi + ecc_real * ecc_real * majority * DATA_size * 8 + 1
        print(f"We have automatically adjusted the DATA size to {DATA_size} to fit into the device/image.")

    if (DATA_size % 512) > 0:
        sys.stderr.write("ERROR: The datasize is not a multiple of 512 Bytes, please check the parameters!\n")
        return -3

    print("Creating old pattern for recovering the FTL")
    while not wearedone:
        p_write_sector = bytearray(p_write_block[(sector & 7) << 9 :])  
        pattern_str = f"|Block#{sector:012d} (0x{sector:08X}) Byte: {sector*512:020d} Pos: {sector>>11:10d} MB\n*** OVERWRITTEN"
        pattern_bytes = pattern_str.encode('utf-8')
        p_write_sector[:len(pattern_bytes)] = pattern_bytes
        if (sector & 7) == 7 and not kernel32.WriteFile(h_device, p_write_block, 4096, ctypes.byref(Ropen), None):
            if get_last_error_string() == "ERROR_SECTOR_NOT_FOUND":
                print("Reached last sector.")
                wearedone = 1
            else:
                print(f"Error when writing: {get_last_error_string()}")
                return 0
        sector += 1
        if not (sector & 0x3ffff):
            print(f"Status: Sector {sector} ({sector//2//1024//1024} GB)")
        if (sector << 9) >= target_size:
            wearedone = 1

    kernel32.SetFilePointer(h_device, 0, None, 0)
    sector = 0
    wearedone = 0
    print("Creating new pattern for recovering XOR and LDPC")
    while not wearedone:
        p_write_sector = bytearray(p_write_block[(sector & 7) << 9 :])  
        if sector == border0:
            p_write_block[:] = bytes(4096)
        elif sector == border7:
            p_write_sector[:] = bytes(4096)
        elif sector == borderf:
            p_write_sector[:] = bytes([0xff] * 4096)
        elif sector < border0 or sector >= borderphi:
            pattern_str = f"|Block#{sector:012d} (0x{sector:08X}) Byte: {sector*512:020d} Pos: {sector>>11:10d} MB\n***"
            pattern_bytes = pattern_str.encode('utf-8')
            p_write_sector[:len(pattern_bytes)] = pattern_bytes
            if sector >= borderphi and sector < border_ecc:
                pattern_size = ecc_real * ecc_real * majority
                offset = sector - borderphi
                pattern = offset // pattern_size
                pattern_pos = offset % ecc_real
                pattern_mod = (offset % (ecc_real * ecc_real)) // ecc_real
                bit_target_sector = ((pattern >> 3) >> 9)
                if pattern_pos > 0:
                    pattern_str = f"P{pattern:011X}{pattern_pos:04X}"
                    pattern_bytes = pattern_str.encode('utf-8')
                    p_write_sector[:len(pattern_bytes)] = pattern_bytes
                    for tgt in range(16, 512, 16):
                        p_write_sector[tgt:tgt + 16] = p_write_sector[:16]
                    if bit_target_sector == (pattern_pos - 1) and (pattern_mod & 1):
                        bit_target_byte = (pattern >> 3) & 0x1FF
                        bit_target_bit = pattern & 7
                        p_write_sector[bit_target_byte] ^= 1 << bit_target_bit

        if (sector & 7) == 7 and not kernel32.WriteFile(h_device, p_write_block, 4096, ctypes.byref(Ropen), None):
            if get_last_error_string() == "ERROR_SECTOR_NOT_FOUND":
                print("Reached last sector.")
                wearedone = 1
            else:
                print(f"Error when writing: {get_last_error_string()}")
                return 0
        sector += 1
        if not (sector & 0x3ffff):
            print(f"Status: Sector {sector} ({sector//2//1024//1024} GB)")
        if (sector << 9) >= target_size:
            wearedone = 1

    kernel32.DeviceIoControl(h_device, 0x00090008, None, 0, None, 0, ctypes.byref(Ropen), None)
    kernel32.CloseHandle(h_device)
    print("We are done writing the pattern.")
    handle = open(xml_fn, "w")
    handle.write("<root overwritten='1'>\n")
    handle.write(f"<device>{argv[1]}</device>\n")
    handle.write(f"<pattern type='sectornumber' begin='0' end='{border0 - 1}' size='{border0}'/>\n")
    handle.write(f"<pattern type='XOR-00' begin='{border0}' end='{border7 - 1}' size='{border7 - border0}'/>\n")
    handle.write(f"<pattern type='XOR-77' begin='{border7}' end='{borderf - 1}' size='{borderf - border7}'/>\n")
    handle.write(f"<pattern type='XOR-FF' begin='{borderf}' end='{borderphi - 1}' size='{borderphi - borderf}'/>\n")
    handle.write(f"<pattern type='ECC' begin='{borderphi}' end='{border_ecc - 1}' size='{border_ecc - borderphi}' coverage='{DATA_size}' majority='{majority}'/>\n")
    handle.write(f"<pattern type='sectornumber' begin='{border_ecc}' end='{target_size//512 - 1 if target_size//512 > border_ecc else -1}' size='{target_size//512 - border_ecc if target_size//512 > border_ecc else -1}'/>\n")
    handle.write("</root>\n")
    handle.close()
    print(f"The configuration has been written to {xml_fn}. Please provide this file too in the end.")
    print("Please wait a couple of seconds to make sure everything has been written, then eject the drive properly. Then connect the NAND flash and dump it.")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
