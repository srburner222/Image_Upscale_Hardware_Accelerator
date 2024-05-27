# This script automates the verification process for the associated upscaling algorithm.

# This is accomplished through converting an input image to a trace file, automatically
# cleaning then running sim-rtl, then converting the output of sim-rtl into a viewable
# upscaled image. This script also reports the performance metrics of the design vs
# an identical upscaling algorithm implemented in this script.

from PIL import Image
import numpy as np
import cv2
import subprocess
import time
import os


# Function to turn an image (.jpg) to a 3D matrix (R,G,B)
def image_to_rgb_matrix(image_path):
    # Open the image
    image = Image.open(image_path)
    
    # Convert the image to RGB mode (in case it's not already)
    image = image.convert('RGB')
    
    # Get the size of the image
    width, height = image.size
    
    # Split the image into R, G, and B components
    r, g, b = image.split()
    
    # Convert the R, G, and B components to numpy arrays
    r_array = np.array(r)
    g_array = np.array(g)
    b_array = np.array(b)
    
    # Create a 3D matrix to represent the image, with dimensions (height, width, 3)
    rgb_matrix = np.zeros((height, width, 3), dtype=np.uint8)
    
    # Assign the R, G, and B components to the corresponding channels in the matrix
    rgb_matrix[:,:,0] = r_array
    rgb_matrix[:,:,1] = g_array
    rgb_matrix[:,:,2] = b_array
    
    return rgb_matrix


# Function to turn matrix from decimal to binary
def rgb_decimal_to_binary(rgb_matrix):
    # Convert decimal RGB values to binary representation
    binary_matrix = np.vectorize(np.binary_repr)(rgb_matrix, width=8)
    return binary_matrix

# Function to combine each element of 3D matrix (8-bit) into a single valued (24-bit) list
def combine_binary_to_24_bit(binary_matrix):
    combined_numbers = []
    height, width, _ = binary_matrix.shape
    for i in range(height):
        for j in range(width):
            combined = 0
            for k in range(3):
                combined = (combined << 8) | int(''.join(str(bit) for bit in binary_matrix[i, j, k]), 2)
            # Format the combined number as a binary string with leading zeros to ensure it has 24 bits
            combined_binary = format(combined, '024b')
            # Append op-code & 52 zeros to the front of the binary string
            combined_binary = '0001' + ('0' * 52) + combined_binary
            combined_numbers.append(combined_binary)
    return combined_numbers

# Function to write binary data (R,G,B) to a text file
def write_combined_numbers_to_file(combined_numbers, filename):
    with open(filename, 'w') as f:
        for num in combined_numbers:
            f.write(f"{num}\n")
            
        # Append trace file with a bunch of empty cycles to ensure proper runtime
        f.write(f"01100000000000000000000000000000000000000000000011111111111111111111111111111111\n")
        f.write(f"01010000000000000000000000000000000000000000000000000000000000000000000000000000\n")
        f.write(f"00110000000000000000000000000000000000000000000000000000000000000000000000000000")


# Function to write module parameters to a vh file
def write_params (filename, image_path):
    image = Image.open(image_path)
    width, height = image.size

    # Write the parameters into the file
    with open(filename, 'w') as f:
        f.write(f" localparam HRES = {width};\n localparam VRES = {height};")

# Function to change the type of module hierarchy used for writing the output file
def write_sim_path (filename, simtype):
    with open(filename, 'w') as f:
        # If not doing sim rtl, use this type
        if(simtype > 1):
            f.write(f"`define SIM_TYPE")
        # If doing sim-rtl, use this one
        else:
            f.write(f"\n")

# Run relevant sim type
def sel_sim_type (sim_type):
    if(sim_type == 1):
        subprocess.run("make sim-rtl", shell = True)
    elif(sim_type == 2):
        subprocess.run("make sim-syn", shell = True)
    elif(sim_type == 3):
        subprocess.run("make sim-par", shell = True)

# Function to parse the output from the DUT into a viewable image
def parse_image (filename, image_path):
    
    # Read in the image and extract the resolution
    image = Image.open(image_path)
    h_res, v_res = image.size
    
    # Produce new resolution values
    new_v_res = 2 * v_res
    new_h_res = 2 * h_res

    #Create image array & load file for module outputs
    outimage = np.zeros((new_v_res, new_h_res, 3))
    outfile = np.loadtxt("Outfile/out.txt")

    #Process output file into image array
    for i in range(0, new_v_res):
        for j in range (0, new_h_res):
            outimage[i, j, 0] = outfile[(i*new_h_res + j)*3 + 2]
            outimage[i, j, 1] = outfile[(i*new_h_res + j)*3 + 1]
            outimage[i, j, 2] = outfile[(i*new_h_res + j)*3 + 0]
    path = "Output_Images/" + filename

    #Write images to output
    cv2.imwrite(path, outimage)

# Function to perform an integer division by 2 for a 3-element array
def intdiv2 (data):
    result = np.zeros(3)
    for i in range (3):
        result[i] = int(data[i]/2)
    return result

# Function to perform and compare the Python implementation of the upscale
# algorithm vs the accelerated version.
def race (image):
    
    # Read in the input image
    image_cv2 = cv2.imread(image)

    # Convert image to numpy array
    image_array = np.asarray(image_cv2)

    # Find dimensions & create new ones
    h_res = image_array.shape[0]
    v_res = image_array.shape[1]
    new_h_res = 2 * h_res
    new_v_res = 2 * v_res

    # Create numpy array for new image
    new_image = np.zeros((new_h_res, new_v_res, 3))

    # Find initial time for performance calculation (directly before compute)
    initial_time = time.time()

    # Put old image in relevant pixel locations for new image
    for i in range(h_res):
        for j in range(v_res):
            new_image[2 * i, 2 * j,:] = image_array [i, j, :]

    # Compute linear values
    for i in range(h_res):
        for j in range(v_res):
            if(i == h_res - 1):
                new_image[2 * i + 1, 2 * j,:] = intdiv2(new_image[2 * i, 2 * j, :])
            else:
                new_image[2 * i + 1, 2 * j,:] = intdiv2(new_image[2 * i, 2 * j, :]) + intdiv2(new_image[2 * i + 2, 2 * j, :])

    # Compute cubic values
    for i in range(new_h_res):
        for j in range(v_res):

            # Left edge edge-case
            if(j == 0):
                in0 = np.zeros(3)
            else:
                in0 = new_image[i, 2 * j - 3,:]

            # Near-left
            in1 = new_image[i, 2 * j,:]

            # Near-right edge edge-case
            if(j >= v_res - 2):
                in3 = np.zeros(3)
            else:
                in3 = new_image[i, 2 * j + 4,:]

            # Far-right edge edge-case
            if(j == v_res - 1):
                in2 = np.zeros(3)
            else:
                in2 = in4 = new_image[i, 2 * j + 2,:]

                # Compute coefficients
                t0 = in1
                t1 = intdiv2(in2) - intdiv2(in0)
                t2 = in0 - (2 * in1 + intdiv2(in1)) + 2 * in2 - intdiv2(in3)
                t3 = -1 * intdiv2(in0) + in1 + intdiv2(in1) - (in2 + intdiv2(in2)) + intdiv2(in3)

                # Final computation
                t32 = intdiv2(t3) + t2
                t321 = intdiv2(t32) + t1
                t3210 = intdiv2(t321) + t0

                # Check for over/underflow
                for color in range(3):
                    if(t3210[color] < 0):
                        t3210[color] = 0
                    elif(t3210[color] > 255):
                        t3210[color] = 255

                # Assign cubic pixel to array
                new_image[i, 2 * j + 1, :] = t3210
    
    # Get end time of run
    final_time = time.time()
    
    # Compute overall runtime in seconds
    runtime = final_time - initial_time

    # Compute various statistics
    fps = 1/runtime
    accelerated_fps = 263157895 / (new_h_res * new_v_res + new_h_res*2 + 1)
    performance_ratio = accelerated_fps/fps

    # Assemble various strings to display performance metrics
    ratio = "\nFor an image upscale of " + str(v_res) + "x" + str(h_res) + " --> " + str(new_v_res) + "x" + str(new_h_res) +  ":"
    softrun = "\nTotal software runtime is " + str(runtime) + " seconds"
    softfps = "This software runtime is equivalent to: " + str(fps) + " Frames Per Second (FPS)\n"
    accfps = "The accelerator runtime (at a period of 3.8ns) is equivalent to: " + str(accelerated_fps) + " Frames Per Second (FPS)\n"
    perf = "Overall, the performance ratio (accelerated:software) is: " + str(performance_ratio) + "\n"
    
    # Print out performance metrics
    print("#############################################################################################################")
    print("                                      +---------------------+")
    print("                                      | PERFORMANCE METRICS |")
    print("                                      +---------------------+\n")
    print(ratio)
    print(softrun)
    print(softfps)
    print(accfps)
    print(perf)
    print("#############################################################################################################")

# Prompt user for image and read it in
print('Enter desired image name to upscale (include file extension!):')
image_name = input()
print('Select simulation type (1-3): 1) sim-rtl, 2) sim-syn, 3) sim-par')
sim_type = int(input())

# Prep various necessary values
image_path = "Input_Images/" + image_name
matrix = image_to_rgb_matrix(image_path)
binary_matrix = rgb_decimal_to_binary(matrix)
combined_numbers = combine_binary_to_24_bit(binary_matrix)

# Write image to trace file
write_combined_numbers_to_file(combined_numbers, "v/bsg_trace_master_0.tr")

# Write parameters to header file
write_params ("v/parameters.vh", image_path)

# Write sim path
write_sim_path("v/sim_path.vh", sim_type)

# Clean build directory and run sim-rtl
subprocess.run("make clean-build", shell=True)
sel_sim_type(sim_type)

# Compute performance metrics and display
race (image_path)

# Creates Output_Images directory
os.popen("mkdir Output_Images")

# Convert output file to viewable image
parse_image(image_name, image_path)
